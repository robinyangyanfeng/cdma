//------------------------------------------------------------------------------//
// File name		:	dmaw_2_axi.v
// Author				:	Yangyf
// E-mail				:
// Project			:
// Created			:
// Description	:
//	1: All AXI burst are 32bit aligned, use read/write byte enable to mask out
//		the unused bytes.
//	2: Maximal AXI burst length is 16.
//	3: No write cmd outstanding.
//-----------------------------------------------------------------------------//

module	dmaw_2_axi(
		//--- cfg regs
		dma_cmd_sof			,
		dma_busy				,
		cfg_bf					,
		cfg_cf					,
		cfg_dma_halt		,
		
		//--- buf status
		buf_buf_word		,
		
		//--- DMA w inf
		dma_w_req				,
		dma_w_ack				,
		dma_w_addr			,
		dma_w_len				,
		
		dma_w_dvld			,
		dma_wdata				,
		dma_wbe					,
		dma_w_dack			,
		
		//--- AXI master inf
		awid						,
		awaddr					,
		awlen						,
		awsize					,
		awburst					,
		awlock					,
		awcache					,
		awprot					,
		awvalid					,
		awready					,
		
		wid							,
		wdata						,
		wstrb						,
		wlast						,
		wvalid					,
		wready					,
		bid							,
		bresp						,
		bvalid					,
		bready					,
		
		clk							,
		rstn
);

parameter		WCMD_THRES	=	6'd12;

input		wire							clk,	rstn			;
input		wire							dma_cmd_sof			;
input		wire							dma_busy				;
input		wire							cfg_dma_halt		;		//1: halt AXI trasfer
input		wire							cfg_bf					;		//bufferable flag in AXI cmd
input		wire							cfg_cf					;		//cacheable flag in AXI cmd

input		wire		[5:0]			buf_buf_word		;		//cnt from 1

//--- DMA write inf (1D DMA req)
input		wire							dma_w_req				;
output	wire							dma_w_ack				;
input		wire		[31:0]		dma_w_addr			;
input		wire		[15:0]		dma_w_len				;		//byte length, cnt from 0

input		wire							dma_w_dvld			;
input		wire		[31:0]		dma_wdata				;
input		wire		[3:0]			dma_wbe					;		//wdata data byte valid
output	wire							dma_w_dack			;

//--- AXI master inf
output	wire		[3:0]			awid						;		//fixed at 0
output	wire		[31:0]		awaddr					;		//byte addr
output	wire		[3:0]			awlen						;
output	wire		[2:0]			awsize					;
output	wire		[1:0]			awburst					;
output	wire		[1:0]			awlock					;
output	wire		[3:0]			awcache					;
output	wire		[2:0]			awprot					;
output	wire							awvalid					;
input		wire							awready					;

output	wire		[3:0]			wid							;		//fixed	at 0
output	wire		[31:0]		wdata						;
output	wire		[3:0]			wstrb						;
output	wire							wlast						;
output	wire							wvalid					;
input		wire							wready					;
input		wire		[3:0]			bid							;
input		wire		[1:0]			bresp						;
input		wire							bvalid					;
input		wire							bready					;


//--- 1: dma req arbt and change to AXI burst transfer
//---	Check for 4KB boundary

reg			[1:0]		sta						;
parameter		[1:0]		s_idle	=	'd0,	s_arbt	=	'd1,	s_cmd0	=	'd2,	s_cmd1	=	'd3;


wire						dma_w_req_w	;
wire						trans_go		;
wire		[1:0]		gnt_id			;		//1T delay of dma_?_req?
wire		[3:0]		gnt					;
reg			[31:0]	mux_addr		;		//used in s_arbt and s_cmd0, s_cmd1 state
wire		[15:0]	mux_len			;		//used in s_arbt state, cnt from 0
reg			[31:0]	cmd0_addr		;
reg			[11:0]	cmd0_len		;		//1D DMA length divide to 1st cmd, within 4KB boundary
reg			[31:0]	cmd1_addr		;
reg			[15:0]	cmd1_len		;
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
wire signed	[16:0]nxt_bt_len;
wire						bt_cmd_req	;
wire						bt_cmd_ack	;
wire						send_bt_cmd	;		//1'b1: send out a burst cmd
wire		[1:0]		dma_end_bloc;		//dma burst end byte location


assign	dma_w_req_w		=	dma_w_req	&	(sta	==	s_idle)	&	(!cfg_dma_halt);
assign	dma_w_ack			=	gnt[2];

assign	cur_addr			=	(sta	==	s_cmd0)?	cmd0_addr	:	cmd1_addr;
assign	cur_len				=	(sta	==	s_cmd0)?	{4'h0,	cmd0_len}	:	cmd1_len;
assign	nxt_bt_addr		=	cur_addr + cur_bt_byte +	'd3;		//alignt to 32 bit
assign	nxt_bt_len		=	{1'b0,	cur_len}	-	{11'h0,	cur_bt_byte}	-	'd1;

assign	bt_cmd_req		=	(sta	==	s_cmd0)	|	(sta	==	s_cmd1);
assign	send_bt_cmd		=	bt_cmd_req	&	bt_cmd_ack;

//--- keep it as read channel, can support multi-channel DMA later
strict_round_arbt	u_arbt(
		.req0				(1'b0		),
		.req1				(1'b0		),
		.req2				(dma_w_req_w	),
		.req3				(1'b0		),
		
		.gnt0				(gnt[0]				),
		.gnt1				(gnt[1]				),
		.gnt2				(gnt[2]				),
		.gnt3				(gnt[3]				),
		.gnt_id			(gnt_id				),
		
		.clk				(clk					),
		.rstn				(rstn					)
);


assign	trans_go		=	dma_w_req_w;
assign	mux_len			=	dma_w_len;

always @(*)	begin
		case(sta)
		s_idle,	s_arbt:	mux_addr		=	dma_w_addr;
		s_cmd0:					mux_addr		=	cmd0_addr;
		default:				mux_addr		=	cmd1_addr;
		endcase
end

always @(*)	begin
		if(mux_addr[1:0]	!=	'd0)	begin	//begin addr not 32bit aligned
				if(cur_len[15:5]	!=	'd0)		//>=32byte burst
						cur_bt_byte	=	6'd32	-	mux_addr[1:0]	-	'd1;	//align	next	burst addr to 32b,
																												//max AXI burst length is 8 or 9
				else
						cur_bt_byte	=	cur_len[5:0];	//cur_len[5] must be 1'b0
		end else begin
				if(cur_len[15:6]	!=	'd0)		//>=64byte	burst
						cur_bt_byte	=	5'd63;
				else
						cur_bt_byte	=	cur_len[5:0];
		end
end

assign	addr_low_add		=	{1'b0,	mux_addr[11:0]}	+	{1'b0,	mux_len[11:0]};
assign	cross_4kb_w			=	addr_low_add[12]	|	(mux_len[15:12]	!=	'd0);
assign	cmd0_len_cross	=	17'd4096	-	{5'b0,	mux_addr[11:0]}	-	'd1;
assign	cmd1_len_w			=	{1'b0,	mux_len}	-	{5'h0,	cmd0_len_cross[11:0]}	-	'd1;
assign	cmd1_addr_h			=	mux_addr[31:12]	+	1'b1;
assign	dma_end_bloc		=	mux_addr[1:0]	+	mux_len[1:0]	+	1'b1;

always	@(posedge	clk or negedge	rstn)
if(~rstn)	begin
		cross_4kb		<=	'd0;
end	else	if(sta	==	s_arbt)	begin
		cross_4kb		<=	cross_4kb_w;
end

always @(posedge	clk or negedge	rstn)
if(~rstn)	begin
		sta			<=	s_idle;
end	else begin
		case(sta)
		s_idle:	begin
				if(trans_go)	begin
						sta			<=	s_arbt;
				end
		end
		
		s_arbt:	begin
				sta			<=	s_cmd0;
		end
		
		s_cmd0:	begin
				if(send_bt_cmd)	begin
						if(nxt_bt_len[16])	begin
							if(cross_4kb)
									sta			<=	s_cmd1;
							else
									sta			<=	s_idle;
						end	else begin
							sta				<=	s_cmd0;
						end
				end
		end
		
		s_cmd1:	begin
				if(send_bt_cmd)	begin
						if(nxt_bt_len[16]) begin
								sta			<=	s_idle;
						end	else begin
								sta			<=	s_cmd1;
						end
				end
		end
		endcase
end


always	@(posedge	clk or negedge rstn)
if(~rstn)	begin
		cmd0_addr		<=	'd0;
		cmd0_len		<=	'd0;
end	else	if(sta	==	s_arbt)	begin
		cmd0_addr		<=	mux_addr;
		cmd0_len		<=	(cross_4kb_w)?	cmd0_len_cross[11:0]	:	mux_len[11:0];
end	else	if((sta	==	s_cmd0)	&& send_bt_cmd)	begin
		cmd0_addr		<=	{nxt_bt_addr[31:2],	2'h0};
		cmd0_len		<=	nxt_bt_len[11:0];
end

always	@(posedge	clk or negedge	rstn)
if(~rstn)	begin
		cmd1_addr		<=	'd0;
		cmd1_len		<=	'd0;
end	else if((sta	==	s_arbt)	&&	cross_4kb_w)	begin
		cmd1_addr		<=	{cmd1_addr_h,	12'h0};
		cmd1_len		<=	cmd1_len_w;
end	else if((sta	==	s_cmd1)	&&	send_bt_cmd)	begin
		cmd1_addr		<=	{nxt_bt_addr[31:2],	2'h0};
		cmd1_len		<=	nxt_bt_len[15:0];
end

//--- 2: change burst cmd to AXI inf burst cmd ---//
always	