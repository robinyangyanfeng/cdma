//-----------------------------------------//
// File name		: cdma.v
// Author				: Yangyf
// E-mail				:
// Project			:
// Created			:
// Copyright		:
// Description	:
//-----------------------------------------//

module	cdma(
		//--- APB configure inf
		psel					,
		penable				,
		paddr					,
		pwrite				,
		pwdata				,
		pready				,
		prdata				,
		
		//--- AXI inf
		arid					,
		araddr				,
		arlen					,
		arsize				,
		arburst				,
		arlock				,
		arcache				,
		arprot				,
		arvalid				,
		arready				,
		
		rid						,
		rdata					,
		rresp					,
		rlast					,
		rvalid				,
		rready				,
		
		awid					,
		awaddr				,
		awlen					,
		awsize				,
		awburst				,
		awlock				,
		awcache				,
		awprot				,
		awvalid				,
		awready				,
		
		wid						,
		wdata					,
		wstrb					,
		wlast					,
		wvalid				,
		wready				,
		bid						,
		bresp					,
		bvalid				,
		bready				,
		
		intr					,
		
		clk						,
		rstn
);

input		wire					clk, rstn				;

//--- APB configure inf
input		wire					psel						;
input		wire					penable					;
input		wire	[7:0]		paddr						;		//byte addr
input		wire					pwrite					;
input		wire	[31:0]	pwdata					;
output	wire					pready					;
output	wire	[31:0]	prdata					;

//--- AXI inf
output	wire	[3:0]		arid						;		//0~1
output	wire	[31:0]	araddr					;
output	wire	[3:0]		arlen						;
output	wire	[2:0]		arsize					;
output	wire	[1:0]		arburst					;
output	wire	[1:0]		arlock					;
output	wire	[3:0]		arcache					;
output	wire	[2:0]		arprot					;
output	wire					arvalid					;
input		wire					arready					;

input		wire	[3:0]		rid							;
input		wire	[31:0]	rdata						;
input		wire	[1:0]		rresp						;
input		wire					rlast						;
input		wire					rvalid					;
output	wire					rready					;

output	wire	[3:0]		awid						;		//fixed at 0
output	wire	[31:0]	awaddr					;		//byte addr
output	wire	[3:0]		awlen						;
output	wire	[2:0]		awsize					;
output	wire	[1:0]		awburst					;
output	wire	[1:0]		awlock					;
output	wire	[3:0]		awcache					;
output	wire	[2:0]		awprot					;
output	wire					awvalid					;
input		wire					awready					;

output	wire	[3:0]		wid							;		//fixed at 0
output	wire	[31:0]	wdata						;
output	wire	[3:0]		wstrb						;
output	wire					wlast						;
output	wire					wvalid					;
input		wire					wready					;
input		wire	[3:0]		bid							;
input		wire	[1:0]		bresp						;
input		wire					bvalid					;
output	wire					bready					;

output	wire					intr						;

wire		[31:0]	cfg_sar					;		//source byte addr
wire		[31:0]	cfg_dar					;		//destination byte addr
wire		[15:0]	cfg_trans_xsize	;		//2D DMA x-dir transfer byte size, cnt from 0
wire		[15:0]	cfg_trans_ysize	;		//2D DMA y-dir transfer lines, cnt from 0
wire		[15:0]	cfg_sa_ystep		;		//source byte addr offset between each line, cnt from 1
wire		[15:0]	cfg_da_ystep		;		//destination byte addr offset between each line, cnt from 1
wire		[31:0]	cfg_llr					;		//DMA cmd linked list base addr (addr pointer)
wire						cfg_dma_halt		;		//1: halt AXI trasfer
wire						cfg_bf					;		//bufferable flag in AXI cmd
wire						cfg_cf					;		//cacheable flag in AXI cmd

//--- cmd linked list request and ack
wire						ll_req					;		//linked list request, high level active
wire		[31:0]	ll_addr					;		//32bit aligned address
wire						ll_ack					;		//
wire						ll_dvld					;		//linked list	data valid
wire		[31:0]	ll_rdata				;		//linked list	read data
wire		[2:0]		ll_dcnt					;		//linked list read data cnt: 0~7

//--- dma status
wire						dma_cmd_sof			;		//1T high pulse start a DMA cmd (one cmd in a cmd group)
wire						dma_cmd_end			;		//1T high pulse end a DMA cmd
wire		[7:0]		cmd_num					;		//current	processed cmd number, cnt from 1
wire						dma_busy				;		//1: dma is busy with current cmd group
wire						dma_r_req0			;		//1: send out dma req
wire						dma_r_ack0			;
wire		[31:0]	dma_r_addr0			;		//byte addr, may not 32bit align
wire		[15:0]	dma_r_len0			;		//byte length, cnt from 0

wire						dma_dvld0				;		//read data valid
wire						dma_rd_last0		;		//1'b1: last data of a dma_r_req
wire		[31:0]	dma_rdata0			;
wire		[3:0]		dma_rbe0				;		//read data byte valid
wire						dma_dack0				;

wire						dma_r_req1			;		//1: send out dma req
wire						dma_r_ack1			;
wire		[31:0]	dma_r_addr1			;		//byte addr, may not 32bit align
wire		[15:0]	dma_r_len1			;		//byte length, cnt from 0

wire						dma_dvld1				;		//read data valid
wire						dma_rd_last1		;		//1'b1: last data of a dma_r_req
wire		[31:0]	dma_rdata1			;
wire		[3:0]		dma_rbe1				;		//read data byte valid
wire						dma_dack1				;

//--- DMA inf
wire						dma_w_req				;
wire						dma_w_ack				;
wire		[31:0]	dma_w_addr			;
wire		[15:0]	dma_w_len				;		//byte length, cnt from 0
wire						dma_w_dvld			;
wire		[31:0]	dma_wdata				;
wire		[3:0]		dma_wbe					;		//wdata data byte valid
wire						dma_w_dack			;

//--- data buffer wr & sta
wire						buf_wr					;
wire		[31:0]	buf_wdata				;
wire		[5:0]		buf_empty_word	;		//empty 32b space in the data fifo (data phase)
wire						buf_rd					;
wire		[31:0]	buf_rdata				;		//valid same cycle as buf_rd
wire		[5:0]		buf_buf_word		;		//buffered 32b space in the data fifo (data phase)
wire						buf_empty				;
wire						buf_err					;
wire						clr_buf_err			;

cdma_cfg		u_cdma_cfg(
		//--- APB configure inf
		.psel						(psel						),
		.penable				(penable				),
		.paddr					(paddr					),
		.pwrite					(pwrite					),
		.pwdata					(pwdata					),
		.pready					(pready					),
		.prdata					(prdata					),
		
		//--- cfg regs
		.cfg_sar				(cfg_sar				),
		.cfg_dar				(cfg_dar				),
		.cfg_trans_xsize(cfg_trans_xsize),
		.cfg_trans_ysize(cfg_trans_ysize),
		.cfg_sa_ystep		(cfg_sa_ystep		),
		.cfg_da_ystep		(cfg_da_ystep		),
		.cfg_llr				(cfg_llr				),
		.cfg_dma_halt		(cfg_dma_halt		),
		.cfg_bf					(cfg_bf					),
		.cfg_cf					(cfg_cf					),
		
		.buf_err				(buf_err				),
		.clr_buf_err		(clr_buf_err		),
		
		//--- cmd linked list req and ack
		.ll_req					(ll_req					),
		.ll_addr				(ll_addr				),
		.ll_ack					(ll_ack					),
		.ll_dvld				(ll_dvld				),
		.ll_rdata				(ll_rdata				),
		.ll_dcnt				(ll_dcnt				),
		
		//--- dma status
		.dma_cmd_sof		(dma_cmd_sof		),
		.dma_cmd_end		(dma_cmd_end		),
		.cmd_num				(cmd_num				),
		.dma_busy				(dma_busy				),
		.intr						(intr						),
		
		.clk						(clk						),
		.rstn						(rstn						)		
);

cmd_fetch		u_cmd_fetch(
		//--- cmd linked list req and ack
		.ll_req					(ll_req					),
		.ll_addr				(ll_addr				),
		.ll_ack					(ll_ack					),
		.ll_dvld				(ll_dvld				),
		.ll_rdata				(ll_rdata				),
		.ll_dcnt				(ll_dcnt				),
		
		//--- DMA inf
		.dma_r_req			(dma_r_req0			),
		.dma_r_ack			(dma_r_ack0			),
		.dma_r_addr			(dma_r_addr0		),
		.dma_r_len			(dma_r_len0			),
		
		.dma_dvld				(dma_dvld0			),
		.dma_rd_last		(dma_rd_last0		),
		.dma_rdata			(dma_rdata0			),
		.dma_rbe				(dma_rbe0				),
		.dma_dack				(dma_dack0			),
		
		.clk						(clk						),
		.rstn						(rstn						)
);


rcmd_gen		u_rcmd_gen(
		//--- cfg regs
		.dma_cmd_sof		(dma_cmd_sof		),
		.cfg_sar				(cfg_sar				),
		.cfg_trans_xsize(cfg_trans_xsize),
		.cfg_trans_ysize(cfg_trans_ysize),
		.cfg_sa_ystep		(cfg_sa_ystep		),
		
		//--- DMA inf
		.dma_r_req			(dma_r_req1			),
		.dma_r_ack			(dma_r_ack1			),
		.dma_r_addr			(dma_r_addr1		),
		.dma_r_len			(dma_r_len1			),
		
		.dma_dvld				(dma_dvld1			),
		.dma_rd_last		(dma_rd_last1		),
		.dma_rdata			(dma_rdata1			),
		.dma_rbe				(dma_reb1				),
		.dma_dack				(dma_dack1			),
		
		//--- data buffer wr & sta
		.buf_wr					(buf_wr					),
		.buf_wdata			(buf_wdata			),
		.buf_empty_word	(buf_empty_word	),
		
		.clk						(clk						),
		.rstn						(rstn						)
);

wcmd_gen		u_wcmd_gen(
		//--- cfg regs
		.dma_cmd_sof		(dma_cmd_sof		),
		.dma_cmd_end		(dma_cmd_end		),
		.cfg_dar				(cfg_dar				),
		.cfg_trans_xsize(cfg_trans_xsize),
		.cfg_trans_ysize(cfg_trans_ysize),
		.dma_busy				(dma_busy				),
		
		//--- DMA inf
		.dma_w_req			(dma_w_req			),
		.dma_w_ack			(dma_w_ack			),
		.dma_w_addr			(dma_w_addr			),
		.dma_w_len			(dma_w_len			),
		
		.dma_w_dvld			(dma_w_dvld			),
		.dma_wdata			(dma_wdata			),
		.dma_wbe				(dma_wbe				),
		.dma_w_dack			(dma_w_dack			),
		
		//--- data buffer rd & sta
		.buf_rd					(buf_rd					),
		.buf_rdata			(buf_rdata			),
		.buf_buf_word		(buf_buf_word		),
		.buf_empty			(buf_empty			),
		.buf_err				(buf_err				),
		.clr_buf_err		(clr_buf_err		),
		
		.clk						(clk						),
		.rstn						(rstn						)
);

dmar_2_axi	u_dmar_2_axi(
		//--- cfg regs
		.dma_cmd_sof		(dma_cmd_sof		),
		.dma_busy				(dma_busy				),
		.cfg_bf					(cfg_bf					),
		.cfg_cf					(cfg_cf					),
		.cfg_dma_halt		(cfg_dma_halt		),
		
		.buf_empty_word	(buf_empty_word	),
		
		//--- DMA read inf_0
		.dma_r_req0			(dma_r_req0			),
		.dma_r_ack0			(dma_r_ack0			),
		.dma_r_addr0		(dma_r_addr0		),
		.dma_r_len0			(dma_r_len0			),
		
		.dma_dvld0			(dma_dvld0			),
		.dma_rd_last0		(dma_rd_last0		),
		.dma_rdata0			(dma_rdata0			),
		.dma_rbe0				(dma_rbe0				),
		.dma_dack0			(dma_dack0			),
		
		//--- DMA read inf_1
		.dma_r_req1			(dma_r_req1			),
		.dma_r_ack1			(dma_r_ack1			),
		.dma_r_addr1		(dma_r_addr1		),
		.dma_r_len1			(dma_r_len1			),
		
		.dma_dvld1			(dma_dvld1			),
		.dma_rd_last1		(dma_rd_last1		),
		.dma_rdata1			(dma_rdata1			),
		.dma_rbe1				(dma_rbe1				),
		.dma_dack1			(dma_dack1			),
		
		.arid						(arid						),
		.araddr					(araddr					),
		.arlen					(arlen					),
		.arsize					(arsize					),
		.arburst				(arburst				),
		.arlock					(arlock					),
		.arcache				(arcache				),
		.arport					(arport					),
		.arvalid				(arvalid				),
		
		.rid						(rid						),
		.rdata					(rdata					),
		.rresp					(rresp					),
		.rlast					(rlast					),
		.rvalid					(rvalid					),
		.rready					(rready					),
		
		.clk						(clk						),
		.rstn						(rstn						)
);


dmaw_2_axi	u_dmaw_2_axi(
		//--- cfg regs
		.dma_cmd_sof		(dma_cmd_sof		),
		.dma_busy				(dma_busy				),
		.cfg_bf					(cfg_bf					),
		.cfg_cf					(cfg_cf					),
		.cfg_dma_halt		(cfg_dma_halt		),
		.buf_buf_word		(buf_buf_word		),
		
		//--- DMA w inf
		.dma_w_req			(dma_w_req			),
		.dma_w_ack			(dma_w_ack			),
		.dma_w_addr			(dma_w_addr			),
		.dma_w_len			(dma_w_len			),
		
		.dma_w_dvld			(dma_w_dvld			),
		.dma_wdata			(dma_wdata			),
		.dma_wbe				(dma_wbe				),
		.dma_w_dack			(dma_w_dack			),
		
		//--- AXI master inf
		.awid						(awid						),
		.awaddr					(awaddr					),
		.awlen					(awlen					),
		.awsize					(awsize					),
		.awburst				(awburst				),
		.awlock					(awlock					),
		.awcache				(awcache				),
		.awprot					(awprot					),
		.awvalid				(awvalid				),
		.awready				(awready				),
		
		.wid						(wid						),
		.wdata					(wdata					),
		.wstrb					(wstrb					),
		.wlast					(wlast					),
		.wvalid					(wvalid					),
		.wready					(wready					),
		.bid						(bid						),
		.bresp					(bresp					),
		.bvalid					(bvalid					),
		.bready					(bready					),
		
		.clk						(clk						),
		.rstn						(rstn						)
);


cdma_buf u_cdma_buf(
		.buf_wr					(buf_wr					),
		.buf_wdata			(buf_wdata			),
		.buf_empty_word	(buf_empty_word	),
		
		.buf_rd					(buf_rd					),
		.buf_rdata			(buf_rdata			),
		.buf_buf_word		(buf_buf_word		),
		.buf_empty			(buf_empty			),
		
		.clk						(clk						),
		.rstn						(rstn						)
);

endmodule