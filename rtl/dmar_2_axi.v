//------------------------------------------------------------------------------//
// File name		:	dmar_2_axi.v
// Author				: Yangyf
// E-mail				:
// Project			:
// Created			:
// Description	:
//	1: All AXI burst are 32bit aligned, use read/write byte enable to mask out
//		the unused bytes.
//	2: Maximal AXI burst length is 16.
//	3: Read cmd outstanding is constrainted in a 1D DMA.
//-----------------------------------------------------------------------------//

module	dmar_2_axi(
		//--- cfg regs
		dma_cmd_sof			,
		dma_busy				,
		cfg_bf					,
		cfg_cf					,
		cfg_dma_halt		,
		
		//--- buffer	status
		buf_empty_word	,
		
		//--- DMA read inf_0
		dma_r_req0			,
		dma_r_ack0			,
		dma_r_addr0			,
		dma_r_len0			,
		
		dma_dvld0				,
		dma_rd_last0		,
		dma_rdata0			,
		dma_rbe0				,
		dma_dack0				,
		
		//--- DMA read inf_1
		dma_r_req1			,
		dma_r_ack1			,
		dma_r_addr1			,
		dma_r_len1			,
		
		dma_dvld1				,
		dma_rd_last1		,
		dma_rdata1			,
		dma_rbe1				,
		dma_dack1				,
		
		arid						,
		araddr					,
		arlen						,
		arsize					,
		arburst					,
		arlock					,
		arcache					,
		arprot					,
		arvalid					,
		arready					,
		
		rid							,
		rdata						,
		rresp						,
		rlast						,
		rvalid					,
		rready					,
		
		clk							,
		rstn
);


parameter		RCMD_THRES = 6'd8;


input		wire						clk,	rstn			;
input		wire						dma_cmd_sof			;
input		wire						dma_busy				;
input		wire						cfg_dma_halt		;		//1: halt AXI transfer
input		wire						cfg_bf					;		//bufferable flag in AXI cmd
input		wire						cfg_cf					;		//cacheable flag in AXI cmd

input		wire		[5:0]		buf_empty_word	;		//empty 32b space in the data fifo (data phase)

//--- DMA read inf_0 & _1 (1D DMA req)
input		wire						dma_r_req0			;		//1: send out dma req
output	wire						dma_r_ack0			;
input		wire		[31:0]	dma_r_addr0			;		//byte addr, may not 32bit align
input		wire		[15:0]	dma_r_len0			;		//byte length, cnt from 0

output	wire						dma_dvld0				;		//read data valid
output	wire						dma_rd_last0		;		//1'b1: last data of a dma_r_req
output	wire		[31:0]	dma_rdata0			;
output	wire		[3:0]		dma_rbe0				;		//read data byte valid
input		wire						dma_dack0				;

input		wire						dma_r_req1			;		//1: send out dma req
output	wire						dma_r_ack1			;
input		wire		[31:0]	dma_r_addr1			;		//byte addr, may not 32bit align
input		wire		[15:0]	dma_r_len1			;		//byte length, cnt from 0

output	wire						dma_dvld1				;		//read data valid
output	wire						dma_rd_last1		;		//1'b1: last data of a dma_r_req
output	wire		[31:0]	dma_rdata1			;
output	wire		[3:0]		dma_rbe1				;		//read data byte valid
input		wire						dma_dack1				;

output	wire		[3:0]		arid						;		//0~1
output	wire		[31:0]	araddr					;
output	wire		[3:0]		arlen						;
output	wire		[2:0]		arsize					;
output	wire		[1:0]		arburst					;
output	wire		[1:0]		arlock					;
output	wire		[3:0]		arcache					;
output	wire		[2:0]		arprot					;
output	wire						arvalid					;
input		wire						arready					;

input		wire		[3:0]		rid							;
input		wire		[31:0]	rdata						;
input		wire		[1:0]		rresp						;
input		wire						rlast						;
input		wire						rvalid					;
output	wire						rready					;


//--- 1: dma req arbt and change to AXI burst transfer
//--- Check for 4KB boundary

reg			[2:0]		sta					;			//1D DMA sta
parameter		s_idle	=	'd0,	s_arbt	=	'd1,	s_cmd0	=	'd2,	s_cmd1	=	'd3,	s_d_end	=	'd4;


wire						dma_r_req0_w;
wire						dma_r_req1_w;
wire						trans_go		;
wire		[1:0]		gnt_id			;		//1T delay of dma_?_req?
wire		[3:0]		gnt					;
reg			[31:0]	mux_addr		;		//used in s_arbt and s_cmd0, s_cmd1 state
reg			[15:0]	mux_len			;		//used in s_arbt state, cnt from 0
reg			[15:0]	dma_byte_remain;	//remain byte number need read back in a 1D DMA, cnt from 0
reg	signed	[16:0]	nxt_byte_remain;
reg			[3:0]		dma_rbe			;
reg			[31:0]	cmd0_addr		;
reg			[11:0]	cmd0_len		;		//1D DMA length divide to 1st cmd, within 4KB boundary, cnt from 0
reg			[31:0]	cmd1_addr		;
reg			[15:0]	cmd1_len		;		//cnt from 0
wire		[12:0]	addr_low_add;		//for cross 4KB boundary check (just check for first cross point)
																//as later burst length are fixed at 16, never cross 4KB again
wire						cross_4kb_w	;
reg							cross_4kb		;
wire		[16:0]	cmd0_len_cross;	//cnt from 0
wire		[16:0]	cmd1_len_w	;
wire		[19:0]	cmd1_addr_h	;

wire		[31:0]	cur_addr		;
wire		[15:0]	cur_len			;		//cnt from 0
reg			[5:0]		cur_bt_byte	;		//current burst byte length, cnt from 0
wire		[31:0]	nxt_bt_addr	;
wire	signed	[16:0]nxt_bt_len;	//remain	1D DMA burst byte length after this trans
wire						bt_cmd_req	;
wire	signed	[6:0]	buf_empty_sub_thres;	//not accurate(maybe cmd phase info is better)
wire						buf_has_space;	//make sure will not halt the AXI bus too much at read data channel
wire						bt_cmd_ack	;
wire						sen_bt_cmd	;		//1'b1: send out a burst cmd

wire		[1:0]		dma_end_bloc;		//dma burst end byte location
reg			[3:0]		dma_r_fir_be;		//first data byte enable for a dma_r_req?
reg			[3:0]		dma_r_last_be;	//last data byte enable for a dma_r_req?
reg			[1:0]		last_vld_byte;	//last beat valid byte in a 1D DMA, cnt from 0

wire						ch0_d_trans	;
wire						ch1_d_trans	;
wire						dma_d_trans	;
wire						last_rdata	;
reg							first_d_flag;		//1'b1: first read back data in a 1D DMA
reg			[2:0]		first_vld_byte;

assign	dma_r_req0_w		=	dma_r_req0 & (sta == s_idle) & (!cfg_dma_halt);
assign	dma_r_req1_w		=	dma_r_req1 & (sta == s_idle) & (!cfg_dma_halt);

assign	dma_r_ack0			=	gnt[0];
assign	dma_r_ack1			=	gnt[1];

assign	cur_addr				=	(sta == s_cmd0)?	cmd0_addr	:	cmd1_addr;
assign	cur_len					=	(sta == s_cmd0)?	{4'h0,	cmd0_len}	:	cmd1_len;
assign	nxt_bt_addr			=	cur_addr	+	cur_bt_byte	+	'd3;			//align to 32b it
assign	nxt_bt_len			=	{1'b0,	cur_len}	-	{11'h0,	cur_bt_byte}	-	'd1;

assign	buf_empty_sub_thres	=	{1'b0,	buf_empty_word}	-	{1'b0,	RCMD_THRES};
assign	buf_has_space		=	(buf_empty_sub_thres[6])?	1'b0	:	1'b1;
assign	bt_cmd_req			=	((sta	==	s_cmd0)	|	(sta	==	s_cmd1))	&	(!cfg_dma_halt)	&	buf_has_space;
assign	send_bt_cmd			=	bt_cmd_req	&	bt_cmd_ack;

assign	dma_dvld0				=	rvalid	&	(rid[1:0]	==	'd0);
assign	ch0_d_trans			=	dma_dvld0	&	dma_dack0;
assign	dma_dvld1				=	rvalid	&	(rid[1:0]	==	'd1);
assign	ch1_d_trans			=	dma_dvld1	&	dma_dack1;
assign	dma_d_trans			=	ch0_d_trans	|	ch1_d_trans;

strict_round_arbt	u_arbt(
		.req0				(dma_r_req0_w),
		.req1				(dma_r_req1_w),
		.req2				(1'b0		),
		.req3				(1'b0		),
		
		.gnt0				(gnt[0]			),
		.gnt1				(gnt[1]			),
		.gnt2				(gnt[2]			),
		.gnt3				(gnt[3]			),
		.gnt_id			(gnt_id			),
		
		.clk				(clk				),
		.rstn				(rstn				)
);


assign	trans_go		=	dma_r_req0_w	|	dma_r_req1_w;

always	@(*)	begin
		if(gnt_id[0]	==	1'b0)
				mux_len			=	dma_r_len0;
		else
				mux_len			=	dma_r_len1;
				
				
		case(sta)
		s_idle,	s_arbt:	begin
				if(gnt_id[0]	==	1'b0)
						mux_addr		=	dma_r_addr0;
				else
						mux_addr		=	dma_r_addr1;
		end
		
		s_cmd0:	mux_addr		=	cmd0_addr;
		default:mux_addr		=	cmd1_addr;
	endcase

end

always @(*)	begin
		if(mux_addr[1:0]	!=	'd0)	begin	//begin addr not 32bit aligned
				if(cur_len[15:5]	!=	'd0)		//>=32byte burst
						cur_bt_byte	=	6'd32	-	mux_addr[1:0]	-	'd1;	//align next burst addr to 32b£¬
																												//max AXI burst length is 8 or 9
				else
						cur_bt_byte	=	cur_len[5:0];	//cur_len[5] must be 1'b0
		end else begin
				if(cur_len[15:6]	!=	'd0)		//>=64byte burst
						cur_bt_byte	=	6'd63;
				else
						cur_bt_byte	=	cur_len[5:0];
		end
end

assign	addr_low_add		=	{1'b0,	mux_addr[11:0]}	+	{1'b0,	mux_len[11:0]};
assign	cross_4kb_w			=	addr_low_add[12]	|	(mux_len[15:12]	!=	'd0);
assign	cmd0_len_cross	=	17'd4096	-	{5'd0,	mux_addr[11:0]}	-	'd1;
assign	cmd1_len_w			=	{1'b0,	mux_len}	-	{5'h0,	cmd0_len_cross[11:0]}	-	'd1;
assign	cmd1_addr_h			=	mux_addr[31:12]	+	1'b1;
assign	dma_end_bloc		=	mux_addr[1:0]	+	mux_len[1:0]	+	1'b1;
assign	last_data				=	nxt_byte_remain[16];

always	@(posedge clk or negedge rstn)
if(~rstn)	begin
		cross_4kb		<=	'd0;
		first_vld_byte<=	'd0;
		dma_r_fir_be<=	'd0;
		dma_r_last_be<=	'd0;
		last_vld_byte<=	'd0;
end	else	if(sta	==	s_arbt)	begin
		cross_4kb		<=	cross_4kb_w;
		
		case(mux_addr[1:0])
		'd0:	begin	dma_r_fir_be	<=	4'b1111;	first_vld_byte	<=	3'd4;	end
		'd1:	begin	dma_r_fir_be	<=	4'b1110;	first_vld_byte	<=	3'd3;	end
		'd2:	begin	dma_r_fir_be	<=	4'b1100;	first_vld_byte	<=	3'd2;	end
		'd3:	begin	dma_r_fir_be	<=	4'b1000;	first_vld_byte	<=	3'd1;	end
		endcase
		
		case(dma_end_bloc)
		'd0:	begin	dma_r_last_be	<=	4'b1111;	last_vld_byte	<=	'd3;	end
		'd1:	begin	dma_r_last_be	<=	4'b0001;	last_vld_byte	<=	'd0;	end
		'd2:	begin	dma_r_last_be	<=	4'b0011;	last_vld_byte	<=	'd1;	end
		'd3:	begin	dma_r_last_be	<=	4'b0111;	last_vld_byte	<=	'd2;	end
		endcase
end


always	@(posedge	clk or negedge	rstn)
if(~rstn)	begin
		sta			<=	s_idle;
end	else	begin
		case(sta)
		s_idle:	begin
				if(trans_go)	begin
						sta			<=	s_arbt;
				end
		end
		
		s_arbt: begin
				sta			<=	s_cmd0;
		end
		
		s_cmd0:	begin
				if(send_bt_cmd)	begin
						if(nxt_bt_len[16])	begin
								if(cross_4kb)
										sta			<=	s_cmd1;
								else
										sta			<=	s_d_end;
						end	else	begin
								sta			<=	s_cmd0;
						end
				end
		end
		
		s_cmd1:	begin
				if(send_bt_cmd)	begin
						if(nxt_bt_len[16])	begin
								sta		<=	s_d_end;
						end	else	begin
								sta		<=	s_cmd1;
						end
				end
		end
		
		//-- wait read all the data of current 1D read DMA
		s_d_end:	begin
				if(dma_d_trans	&&	last_rdata)
						sta			<=	s_idle;
		end
		
		default:	begin
						sta			<=	s_idle;
		end
		endcase
end


always @(posedge	clk or negedge	rstn)
if(~rstn)	begin
		cmd0_addr		<=	'd0;
		cmd0_len		<=	'd0;
end	else	if(sta	==	s_arbt)	begin
		cmd0_addr		<=	mux_addr;
		cmd0_len		<=	(cross_4kb_w)?	cmd0_len_cross[11:0]	:	mux_len[11:0];
end	else	if((sta	==	s_cmd0)	&&	send_bt_cmd)	begin
		cmd0_addr		<=	{nxt_bt_addr[31:2],	2'h0};
		cmd0_len		<=	nxt_bt_len[11:0];
end

always	@(posedge	clk or negedge	rstn)
if(~rstn)	begin
		cmd1_addr		<=	'd0;
		cmd1_len		<=	'd0;
end	else	if((sta	==	s_arbt)	&&	cross_4kb_w)	begin
		cmd1_addr		<=	{cmd1_addr_h,	12'h0};
		cmd1_len		<=	cmd1_len_w[15:0];
end	else	if((sta	==	s_cmd1)	&&	send_bt_cmd)	begin
		cmd1_addr		<=	{nxt_bt_addr[31:2],	2'h0};
		cmd1_len		<=	nxt_bt_len[15:0];
end


always	@(*)	begin
		if(first_d_flag)	begin
				nxt_byte_remain	=	dma_byte_remain	-	first_vld_byte;
		end	else	begin
				nxt_byte_remain	=	dma_byte_remain	-	'd4;
		end
end

always	@(posedge	clk or negedge rstn)
if(~rstn)	begin
		dma_byte_remain	<=	'd0;
		first_d_flag		<=	1'b1;
end	else	if(sta	==	s_arbt)	begin
		dma_byte_remain	<=	mux_len;
		first_d_flag		<=	1'b1;
end	else	if(dma_d_trans)	begin
		first_d_flag		<=	1'b0;
		dma_byte_remain	<=	nxt_byte_remain;
end

always	@(*)	begin
		if(first_d_flag)
				dma_rbe	=	dma_r_fir_be;
		else	if(dma_byte_remain[15:2]	==	'd0)
				dma_rbe	=	dma_r_last_be;
		else
				dma_rbe	=	4'b1111;
end


//--- 2: change burst cmd to AXI inf burst cmd ---//

reg							axi_sta			;
wire						axi_cmd_ack	;
wire						axi_wr			;		//0:	read AXI trans; 1:	write AXI trans
reg							axi_r_ch		;		//read channel
reg			[31:0]	axi_addr		;
wire		[10:0]	axi_len_w		;		//cnt from 0
reg			[3:0]		axi_len			;		//must	within 0~15


parameter		[0:0]		axi_idle	=	'd0,	axi_cmd	=	'd1;


assign	axi_wr			=	1'b0;
assign	bt_cmd_ack	=	(axi_sta	==	axi_idle)?	1'b1	:	1'b0;
assign	axi_len_w		=	nxt_bt_addr[12:2]	-	{1'b0,	cur_addr[11:2]};
assign	axi_cmd_ack	=	arready;
assign	rready			=	(axi_r_ch)?	dma_dack1	:	dma_dack0;

always	@(posedge	clk	or	negedge	rstn)
if(~rstn)	begin
		axi_sta			<=	axi_idle;
		axi_len			<=	'd0;
		axi_len			<=	'd0;
		axi_r_ch		<=	'd0;
end	else	begin
		case(axi_sta)
		axi_idle:
				if(bt_cmd_req)	begin
						axi_sta			<=	axi_cmd;
						axi_len			<=	axi_len_w[3:0];
						axi_addr		<=	{cur_addr[31:2],	2'h0};
						axi_r_ch		<=	gnt_id[0];
				end
				
		axi_cmd:
				if(axi_cmd_ack)	begin
						axi_sta			<=	axi_idle;
				end
				
		default:		axi_sta	<=	axi_idle;
		endcase
end

assign	arid		=	{3'h0,	axi_r_ch};	//0~1
assign	araddr	=	axi_addr;	//byte	addr
assign	arlen		=	axi_len	;
assign	arsize	=	3'h2		;
assign	arburst	=	2'b01		;
assign	arlock	=	2'b00		;
assign	arcache	=	{2'b00,	cfg_cf,	cfg_bf};
assign	arprot	=	3'b010	;
assign	arvalid	=	(axi_sta	==	axi_cmd)	&	(!axi_wr);


assign	dma_rd_last0=	last_rdata;
assign	dma_rdata0	=	rdata;
assign	dma_rbe0		=	dma_rbe;

assign	dma_rd_last1=	last_rdata;
assign	dma_rdata1	=	rdata;
assign	dma_rbe1		=	dma_rbe;

endmodule