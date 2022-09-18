//------------------------------------------------------------------------------//
// File name			:	rcmd_gen.v
// Author					:	Yangyf
// E-mail					:
// Project				:
// Created				:
// Copyright			:
// Description		:
//	1: Data in fifo is re-aligned of each DMA line (in a dma_r_req).
//	2: As data buffer depth is just 24, may not buffer all the data in 1 1D DMA,
//		so the dma_dack may goes to 0 when the buffer is almost full.
//------------------------------------------------------------------------------//

module	rcmd_gen(
		//--- cfg regs
		dma_cmd_sof			,
		cfg_sar					,
		cfg_trans_xsize	,
		cfg_trans_ysize	,
		cfg_sa_ystep		,
		
		//--- DMA inf
		dma_r_req				,
		dma_r_ack				,
		dma_r_addr			,
		dma_r_len				,
		
		dma_dvld				,
		dma_rd_last			,
		dma_rdata				,
		dma_rbe					,
		dma_dack				,
		
		//--- data buffer wr & sta
		buf_wr					,
		buf_wdata				,
		buf_empty_word	,
		
		clk							,
		rstn
);

input		wire						clk,	rstn			;
//--- cfg regs
input		wire						dma_cmd_sof			;		//1T pulse start a 2D DMA trans
input		wire		[31:0]	cfg_sar					;
input		wire		[15:0]	cfg_trans_xsize	;		//cnt from 0
input		wire		[15:0]	cfg_trans_ysize	;		//cnt from 0
input		wire		[15:0]	cfg_sa_ystep		;		//cnt from 1

//--- DMA inf
output	wire						dma_r_req				;
input		wire						dma_r_ack				;
output	wire		[31:0]	dma_r_addr			;
output	wire		[15:0]	dma_r_len				;		//byte length, cnt from 0

input		wire						dma_dvld				;
input		wire						dma_rd_last			;		//1'b1: last data of a dma_r_req
input		wire		[31:0]	dma_rdata				;
input		wire		[3:0]		dma_rbe					;		//read data byte valid
output	wire						dma_dack				;

//--- data buffer wr & sta
output	wire						buf_wr					;
output	wire		[31:0]	buf_wdata				;
input		wire		[5:0]		buf_empty_word	;		//empty 32b space in the data fifo (data phase)


//--- 1: divide 2D DMA cmd to 1D DMA req
reg			[1:0]		cmd_sta		;
parameter		[1:0]		s_idle	=	'd0,	s_chk	=	'd2,	s_req	=	'd1;

reg			[15:0]	dma_ycnt	;		//cnt from 0
reg			[31:0]	dma_addr	;

assign	dma_r_req		=	(cmd_sta == s_req)? 1'b1 : 1'b0;
assign	dma_r_addr	=	dma_addr;
assign	dma_r_len		=	cfg_trans_xsize;


always	@(posedge clk or negedge rstn)
if(~rstn) begin
		cmd_sta			<= s_idle;
		dma_addr		<= 'd0;
end else begin
		case(cmd_sta)
		s_idle: begin
				if(dma_cmd_sof) begin
						cmd_sta			<= s_req;
						dma_addr		<= cfg_sar;
				end
		end
		
		s_req: begin
				if(dma_r_ack) begin
						cmd_sta	<= s_chk;
						dma_addr<= dma_addr + cfg_trans_xsize + 'd1;
				end
		end
		
		s_chk: begin
				dma_addr		<= dma_addr + cfg_sa_ystep;
				
				if(dma_ycnt != cfg_trans_ysize) begin
						cmd_sta			<= s_req;
				end else begin
						cmd_sta			<= s_idle;
				end
		end
		
		default:begin
				cmd_sta			<= s_idle;
		end
	endcase
end

always @(posedge clk or negedge rstn)
if(~rstn)
		dma_ycnt		<= 'd0;
else if(dma_cmd_sof)
		dma_ycnt		<= 'd0;
else if((cmd_sta == s_chk))
		dma_ycnt		<= dma_ycnt	+ 'd1;
		

//--- 2: recv 1D DMA read data & write in fifo
//--- Note: all data in fifo are valid bytes, excepts the last data of a 1D cmd;

reg			[7:0]				dbuf0				;
reg			[7:0]				dbuf1				;
reg			[7:0]				dbuf2				;
wire								dma_d_recv	;		//1: recv a dma data
reg			[2:0]				buf_byte		;		//byte number buffered in dbuf?
reg									dma_dlast_r	;		//1T delay of dma_rd_last

wire		[2:0]				nxt_buf_byte0;
wire		[2:0]				nxt_buf_byte1;
wire		[2:0]				nxt_buf_byte2;
wire		[2:0]				nxt_buf_byte3;
wire		[2:0]				nxt_buf_byte;
wire								last_wr_ld	;		//1D cmd last data write in fifo
wire		[31:0]			last_wdata	;
reg			[31:0]			dma_rdata_sf;


assign	dma_dack			=	((buf_empty_word != 'd0)? 1'b1 : 1'b0) & (!dma_dlast_r);		//make sure there is empty space
assign	dma_d_recv		=	dma_dvld & dma_dack;

assign	nxt_buf_byte0	=	{1'b0, buf_byte[1:0]} + {2'h0, dma_rbe[0]};
assign	nxt_buf_byte1	= nxt_buf_byte0 + {2'h0, dma_rbe[1]};
assign	nxt_buf_byte2 = nxt_buf_byte1 + {2'h0, dma_rbe[2]};
assign	nxt_buf_byte3	=	nxt_buf_byte2 + {2'h0, dma_rbe[3]};
assign	nxt_buf_byte	= nxt_buf_byte3;


always @(posedge clk or negedge rstn)
if(~rstn)
		dbuf0		<=	'd0;
else if(dma_d_recv) begin
		if(dma_rbe[0] && (buf_byte[1:0] == 'd0))
				dbuf0		<= dma_rdata[0*8 +: 8];
		else if(dma_rbe[1] && (nxt_buf_byte0[1:0] == 'd0))
				dbuf0		<= dma_rdata[1*8 +: 8];
		else if(dma_rbe[2] && (nxt_buf_byte1[1:0] == 'd0))
				dbuf0		<= dma_rdata[2*8 +: 8];
		else if(dma_rbe[3] && (nxt_buf_byte2[1:0] == 'd0))
				dbuf0		<= dma_rdata[3*8 +: 8];
end

always @(posedge clk or negedge rstn)
if(~rstn)
		dbuf1		<=	'd0;
else if(dma_d_recv) begin
		if(dma_rbe[0] && (buf_byte[1:0] == 'd1))
				dbuf1		<= dma_rdata[0*8 +: 8];
		else if(dma_rbe[1] && (nxt_buf_byte0[1:0] == 'd1))
				dbuf1		<= dma_rdata[1*8 +: 8];
		else if(dma_rbe[2] && (nxt_buf_byte1[1:0] == 'd1))
				dbuf1		<= dma_rdata[2*8 +: 8];
		else if(dma_rbe[3] && (nxt_buf_byte2[1:0] == 'd1))
				dbuf1		<= dma_rdata[3*8 +: 8];
end

always @(posedge clk or negedge rstn)
if(~rstn)
		dbuf2		<=	'd0;
else if(dma_d_recv) begin
		if(dma_rbe[0] && (buf_byte[1:0] == 'd2))
				dbuf2		<= dma_rdata[0*8 +: 8];
		else if(dma_rbe[1] && (nxt_buf_byte0[1:0] == 'd2))
				dbuf2		<= dma_rdata[1*8 +: 8];
		else if(dma_rbe[2] && (nxt_buf_byte1[1:0] == 'd2))
				dbuf2		<= dma_rdata[2*8 +: 8];
		else if(dma_rbe[3] && (nxt_buf_byte2[1:0] == 'd2))
				dbuf2		<= dma_rdata[3*8 +: 8];
end

always @(posedge clk or negedge rstn)
if(~rstn)
		dma_dlast_r	<= 1'b0;
else if(dma_d_recv && dma_rd_last)
		dma_dlast_r	<= 1'b1;
else
		dma_dlast_r	<= 1'b0;
		
always @(posedge clk or negedge	rstn)
if(~rstn)
		buf_byte	<= 'd0;
else if(dma_d_recv)
		buf_byte	<= {1'b0, nxt_buf_byte[1:0]};
else if(dma_dlast_r)
		buf_byte	<= 'd0;
		
always @(*) begin
		case(buf_byte[1:0])
		'd0:	dma_rdata_sf	=	 dma_rdata[0*8 +: 32];
		'd1:	dma_rdata_sf	=	{dma_rdata[0*8 +: 24],	dbuf0};
		'd2:	dma_rdata_sf	=	{dma_rdata[0*8 +: 16],	dbuf1, dbuf0};
		'd3:	dma_rdata_sf	=	{dma_rdata[0*8 +: 8],		dbuf2, dbuf1, dbuf0};
		endcase
end

assign	last_wr_ld			=	dma_dlast_r & (buf_byte[1:0] != 'd0);
assign	last_wdata			=	{8'h0, dbuf2, dbuf1, dbuf0};

assign	buf_wr					=	(dma_d_recv & nxt_buf_byte[2]) | last_wr_ld;
assign	buf_wdata				=	(last_wr_ld)? last_wdata : dma_rdata_sf;

endmodule