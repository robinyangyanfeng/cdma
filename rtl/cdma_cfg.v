//----------------------------------------//
// File name		:	cdma_cfg.v
// Author				:	Yangyf
// Email				:
// Project			:
// Created			:
// Copyright		:
//
// Description	:
// 1:	Configure regs, apb slave interface.
//----------------------------------------//

module	cdma_cfg(
		//--- APB configure	inf
		psel						,
		penable					,
		paddr						,
		pwrite					,
		pwdata					,
		pready					,
		prdata					,
		
		//--- cfg regs
		cfg_sar					,
		cfg_dar					,
		cfg_trans_xsize	,
		cfg_trans_ysize	,
		cfg_sa_ystep		,
		cfg_da_ystep		,
		cfg_llr					,
		cfg_dma_halt		,
		cfg_bf					,
		cfg_cf					,
		
		buf_err					,
		clr_buf_err			,
		
		//--- cmd linked list req and ack
		ll_req					,
		ll_addr					,
		ll_ack					,
		ll_dvld					,
		ll_rdata				,
		ll_dcnt					,
		
		//--- dma status
		dma_cmd_sof			,
		dma_cmd_end			,
		cmd_num					,
		dma_busy				,
		intr						,
		
		clk							,
		rstn
);

input		wire						clk, rstn				;
output	wire						intr						;		//high level active
//--- APB configure inf
input		wire						psel						;
input		wire						penable					;
input		wire		[7:0]		paddr						;		//byte addr
input		wire						pwrite					;
input		wire		[31:0]	pwdata					;
output	wire						pready					;
output	wire		[31:0]	prdata					;

//--- cfg regs
output	reg			[31:0]	cfg_sar					;		//source byte addr
output	reg			[31:0]	cfg_dar					;		//destination byte addr
output	reg			[15:0]	cfg_trans_xsize	;		//2D DMA x-dir transfer byte size, cnt from 0
output	reg			[15:0]	cfg_trans_ysize	;		//2D DMA y-dir transfer lines, cnt from 0
output	reg			[15:0]	cfg_sa_ystep		;		//source byte addr offset between each line, cnt from 1
output	reg			[15:0]	cfg_da_ystep		;		//destination byte addr offset between each line, cnt from 1
output	reg			[31:0]	cfg_llr					;		//DMA cmd linked list base addr (addr pointer)
output	reg							cfg_dma_halt		;		//1: halt AXI transfer
output	reg							cfg_bf					;		//bufferable flag in AXI cmd
output	reg							cfg_cf					;		//cacheable flag in AXI cmd

input		wire						buf_err					;
output	wire						clr_buf_err			;

//--- cmd linked list request and ack
output	wire						ll_req					;		//linked list request, high level active
output	wire		[31:0]	ll_addr					;		//32bit aligned address
input		wire						ll_ack					;		//
input		wire						ll_dvld					;		//linked list data valid
input		wire		[31:0]	ll_rdata				;		//linked list read data
input		wire		[2:0]		ll_dcnt					;		//linked list read data cnt: 0~7

//--- dma status
output	reg							dma_cmd_sof			;		//1T high pulse start a DMA cmd (one cmd in a cmd group)
input		wire						dma_cmd_end			;		//1T high pulse end a DMA cmd
output	reg			[7:0]		cmd_num					;		//current processed cmd number, cnt from 1
output	reg							dma_busy				;		//1: dma is busy with current cmd group

//--- apb inf
wire						apb_write				;
wire						apb_read				;
wire		[3:0]		apb_addr				;		//32b addr
wire						clr_intr				;
wire						cmd_update			;
wire		[3:0]		cmd_update_addr	;
wire		[31:0]	cmd_update_wd		;

wire						dma_sof_w				;
reg							cfg_intr_en			;


assign	apb_write				=	psel & pwrite	&	penable;
assign	apb_read				=	psel & (!pwrite);
assign	apb_addr				=	paddr[2 +: 4];
assign	pready					=	1'b1;
assign	clr_intr				= apb_write & penable & (apb_addr == 'd6) & (!pwdata[0]);
assign	dma_sof_w				= apb_write & penable	& (apb_addr == 'd8) & pwdata[0];
assign	clr_buf_err			= apb_write & penable & (apb_addr == 'd6) & (!pwdata[4]);

assign	cmd_update			=	apb_write | ll_dvld;
assign	cmd_update_addr	=	apb_write? apb_addr : {1'b0, ll_dcnt};
assign	cmd_update_wd		=	apb_write? pwdata		:	ll_rdata;


//--- 1: write to regs
always @(posedge	clk or negedge rstn)
if(!rstn) begin
	cfg_sar					<=	'd0;
	cfg_dar					<=	'd0;
	cfg_trans_xsize	<=	'd0;
	cfg_trans_ysize	<=	'd0;
	cfg_sa_ystep		<=	'd0;
	cfg_da_ystep		<=	'd0;
	cfg_llr					<=	'd0;
end else if(cmd_update) begin
		case(cmd_update_addr[3:0])
		'd0:		cfg_sar	<=	cmd_update_wd;
		'd1:		cfg_dar	<=	cmd_update_wd;
		'd2:		cfg_trans_xsize	<=	cmd_update_wd[15:0];
		'd3:		cfg_trans_ysize	<=	cmd_update_wd[15:0];
		
		'd4:		begin
						cfg_sa_ystep		<=	cmd_update_wd[15:0];
						cfg_da_ystep		<=	cmd_update_wd[31:16];
						end
		
		'd5:		cfg_llr		<=	cmd_update_wd;
		default:begin
						end
		endcase
end

always @(posedge	clk or negedge	rstn)
if(!rstn) begin
		cfg_dma_halt		<=	'd0;
		cfg_intr_en			<=	'd0;
		cfg_bf					<=	'd0;
		cfg_cf					<=	'd0;
end else if(apb_write && (apb_addr == 'd7)) begin
		cfg_intr_en			<=	pwdata[0];
		cfg_dma_halt		<=	pwdata[4];
		cfg_bf					<=	pwdata[8];
		cfg_cf					<=	pwdata[9];
end


//--- 2: DMA linked list ctrl
reg			[0:0]				ll_sta			;
wire								dma_end_w		;
reg									dma_end_flag;
parameter		[0:0]		s_idle	=	'd0,	s_req	=	'd1;	//s_wait	=	'd2;

assign	ll_addr			=	cfg_llr;
assign	ll_req			=	(ll_sta	==	s_req)?	1'b1	:	1'b0;
assign	dma_end_w		=	dma_cmd_end	&&	(cfg_llr[31:2]	==	'd0);

always	@(posedge	clk	or	negedge	rstn)
if(!rstn)
		ll_sta	<=	s_idle;
else	begin
		case(ll_sta)
		s_idel:	begin
				if(dma_cmd_end	&&	(cfg_llr[31:2]	!=	'd0))	begin
						ll_sta	<=	s_req;
				end
		end
		
		s_req:	begin
				if(ll_ack)
						//ll_sta	<=	s_wait;
						ll_sta	<=	s_idle;
		end
		
//		s_wait:	begin
//				if(ll_dvld)
//						ll_sta	<=	s_idle;
//		end
		endcase
end

//--- 3: DMA status

wire				dma_cmd_goon		;

assign	dma_cmd_goon		=	ll_dvld	&	(ll_dcnt	==	'd5);

always	@(posedge	clk	or	negedge	rstn)
if(!rstn)
		cmd_num			<=	'd0;
else	if(dma_sof_w)
		cmd_num			<=	'd0;
else	if(dma_cmd_end)
		cmd_num			<=	cmd_num	+	'd1;
		
always	@(posedge	clk	or	negedge	rstn)
if(!rstn)
		dma_busy		<=	1'b0;
else	if(dma_sof_w)
		dma_busy		<=	1'b1;
else	if(dma_end_w)
		dma_busy		<=	1'b0;
		
always	@(posedge	clk	or	negedge	rstn)
if(!rstn)
		dma_cmd_sof	<=	1'b0;
else	if(dma_sof_w	||	dma_cmd_goon)
		dma_cmd_sof	<=	1'b1;
else
		dma_cmd_sof	<=	1'b0;
		

//---	4:	apb read out
always	@(posedge	clk	or	negedge	rstn)
if(!rstn)
		prdata	<=	32'h0;
else	if(apb_read)	begin
		case(apb_addr[3:0])
		'd0:		prdata	<=	cfg_sar;
		'd1:		prdata	<=	cfg_dar;
		'd2:		prdata	<=	{16'h0,	cfg_trans_xsize};
		'd3:		prdata	<=	{16'h0,	cfg_trans_ysize};
		'd4:		prdata	<=	{cfg_da_ystep,	cfg_sa_ystep};
		'd5:		prdata	<=	cfg_llr;
		
		'd6:		prdata	<=	{16'h0,	cmd_num,
													3'h0,	buf_err,	2'h0,	dma_busy,	dma_end_flag};
													
		'd7:		prdata	<=	{22'h0,	cfg_cf,	cfg_bf,
													3'h0,	cfg_dma_halt,	3'h0,	cfg_intr_en};
													
		'd8:		prdata	<=	'd0;
		'd9:		prdata	<=	'd0;
		'd10:		prdata	<=	'd0;
		'd11:		prdata	<=	{16'h0,	16'h5310};
		default:prdata	<=	32'h0;
	endcase
end

endmodule