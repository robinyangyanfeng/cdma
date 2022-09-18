//------------------------------------------------------------------------------//
// File name			: wcmd_gen.v
// Author					: Yangyf
// E-mail					:
// Project				:
// Created				:
// Copyright			:
// Description		:
// 1: Data in fifo is re-aligned of each DMA line (in a dma_w_req).
// 2: As data buffer depth is just 24, may not buffer all the data in 1 1D DMA,
//    so the dma_w_dvld may goes to 0 when the buffer is empty.
//-----------------------------------------------------------------------------//

module	wcmd_gen(
		//--- cfg regs
		dma_cmd_sof			,
		dma_cmd_end			,
		cfg_dar					,
		cfg_trans_xsize	,
		cfg_trans_ysize	,
		cfg_da_ystep		,
		dma_busy				,
		
		//--- DMA inf
		dma_w_req				,
		dma_w_ack				,
		dma_w_addr			,
		dma_w_len				,
		
		dma_w_dvld			,
		dma_wdata				,
		dma_wbe					,
		dma_w_dack			,
		
		//--- data buffer rd & sta
		buf_rd					,
		buf_rdata				,
		buf_buf_word		,
		buf_empty				,
		buf_err					,
		clr_buf_err			,
		
		clk							,
		rstn
);

//parameter		WCMD_THRES = 6'd12;


input		wire						clk, rstn				;
//--- cfg regs
input		wire						dma_cmd_sof			;		//1T pulse start a 2D DMA trans
output	reg							dma_cmd_end			;
input		wire		[31:0]	cfg_dar					;
input		wire		[15:0]	cfg_trans_xsize	;		//cnt from 0
input		wire		[15:0]	cfg_trans_ysize	;		//cnt from 0
input		wire		[15:0]	cfg_da_ystep		;		//cnt from 1
input		wire						dma_busy				;

//--- DMA inf
output	wire						dma_w_req				;
input		wire						dma_w_ack				;
output	wire		[31:0]	dma_w_addr			;
output	wire		[15:0]	dma_w_len				;		//byte length, cnt from 0

output	wire						dma_w_dvld			;
output	wire		[31:0]	dma_wdata				;
output	reg			[3:0]		dma_wbe					;		//wdata data byte valid
input		wire						dma_w_dack			;

//--- data buffer rd & sta
output	wire						buf_rd					;
input		wire		[31:0]	buf_rdata				;		//valid same cycle as buf_rd
input		wire		[5:0]		buf_buf_word		;		//buffered 32b space in the data fifo (data phase)
input		wire						buf_empty				;
output	reg							buf_err					;
input		wire						clr_buf_err			;

//--- 1: divide 2D DMA cmd to 1D DMA req
reg			[1:0]		dma_sta		;
parameter		[1:0]		s_idle = 'd0, s_req = 'd1, s_data = 'd2, s_chk = 'd3;

reg			[15:0]	dma_ycnt		;		//cnt from 0
reg			[31:0]	dma_addr		;
wire		[1:0]		end_bcnt		;		//1D DMA end byte location
reg			[3:0]		fir_wbe			;		//1D DMA first wr byte enable
reg			[3:0]		last_wbe		;		//1D DMA last wr byte enable
reg			[1:0]		align_mode	;		//read shift ctrl after read out from buffer
reg			signed [16:0]	remain_bnum_rd;		//byte number still need read from buffer for a 1D DMA;
																				//when negative, all byte of current 1D DMA has been read out;
reg			signed [16:0]	remain_bnum_send;	//byte number still need send for 1D DMA, cnt from 0
//wire		[5:0]		bnum_sub_thres;		//buffer 32b number sub threshold
//wire		[16:0]	bnum_sub_xlen;		//buffer 32b number 1D DMA length
wire						dma_ld_go		;
wire						send_a_cmd	;
wire						send_a_data	;		//send out a 32b, some byte may be masked
wire						fir_wdata		;


assign	end_bcnt				= dma_addr[1:0] + cfg_trans_xsize[1:0] + 'd1;

//assign	bnum_sub_thres	= {1'b0, buf_buf_word[4:0]} - WCMD_THRES;
//assign	bnum_sub_xlen		= {10'b0, buf_buf_word[4:0], 2'd0} - {1'b0, cfg_trans_xsize};
//assign	dma_ld_go				= ((!bnum_sub_thres[5]) | (!bnum_sub_xlen[16])) & dma_busy;
assign	dma_ld_go				= dma_busy & (buf_buf_word[4:0] != 'd0);		//move data thresthold check to AXI write cmd part

assign	dma_w_req				= (dma_sta == s_req)? 1'b1 : 1'b0;
assign	dma_w_addr			= dma_addr;
assign	dma_w_len				= cfg_trans_xsize;
assign	send_a_cmd			= dma_w_req & dma_w_ack;
assign	send_a_data			= dma_w_dvld & dma_w_dack;
assign	fir_wdata				= send_a_data & (remain_bnum_send[15:0] == cfg_trans_xsize);

always @(posedge clk or negedge rstn)
if(~rstn) begin
		dma_sta			<= s_idle;
		dma_addr		<= 'd0;
		dma_ycnt		<= 'd0;
		remain_bnum_send<= 'd0;
		dma_cmd_end	<= 1'b0;
end else begin
		case(dma_sta)
		s_idle: begin
			dma_cmd_end <= 1'b0;
			if(dma_ld_go) begin
					dma_sta		<= s_req;
					dma_addr	<= cfg_dar;
					dma_ycnt	<= cfg_trans_ysize;
			end
		end
		
		s_req:
				if(dma_w_ack) begin
						dma_sta		<= s_data;
						dma_addr	<= dma_addr + cfg_trans_xsize + 'd1;
						remain_bnum_send<= {1'b0, cfg_trans_xsize};
				end
				
		s_data: begin
				if(remain_bnum_send[16]) begin		//make sure no data overlap between each 1D DMA
						dma_ycnt	<= dma_ycnt - 'd1;
						if(dma_ycnt == 'd0) begin
								dma_sta			<= s_idle;
								dma_cmd_end	<= 1'b1;
						end else
								dma_sta			<= s_chk;
				end
				
				if(send_a_data) begin
						if(fir_wdata) begin		//first beat
							case(align_mode)
							'd0:		remain_bnum_send		<= remain_bnum_send - 'd4;
							'd1:		remain_bnum_send		<= remain_bnum_send - 'd3;
							'd2:		remain_bnum_send		<= remain_bnum_send - 'd2;
							'd3:		remain_bnum_send		<= remain_bnum_send - 'd1;
							endcase
						end else begin
								remain_bnum_send		<= remain_bnum_send - 'd4;
						end
				end
		end
		
		s_chk: begin
				if(dma_ld_go) begin
						dma_addr		<= dma_addr + cfg_da_ystep;
						dma_sta			<= s_req;
				end
		end
		endcase
end


always @(posedge clk or negedge rstn)
if(~rstn)
		buf_err			<= 1'b0;
else if((!dma_busy) && (!buf_empty))
		buf_err			<= 1'b1;
else if(clr_buf_err)
		buf_err			<= 1'b0;
		
always @(posedge clk)		// or negedge rstn)
if(send_a_cmd) begin
		align_mode	<= dma_addr[1:0];
		
		case(dma_addr[1:0])
		'd0:		fir_wbe	<= 4'b1111;
		'd1:		fir_wbe	<= 4'b1110;
		'd2:		fir_wbe	<= 4'b1100;
		'd3:		fir_wbe	<= 4'b1000;
		endcase
		
		case(end_bcnt)
		'd0:		last_wbe<= 4'b1111;
		'd1:		last_wbe<= 4'b0001;
		'd2:		last_wbe<= 4'b0011;
		'd3:		last_wbe<= 4'b0111;
		endcase
end

always @(posedge clk or negedge rstn)
if(!rstn)
		remain_bnum_rd	<= 17'h1_0000;
else if(send_a_cmd)
		remain_bnum_rd	<= cfg_trans_xsize;
else if(buf_rd)
		remain_bnum_rd	<= remain_bnum_rd - 'd4;
		
//--- 2: buf read and data shift
reg	signed [3:0]	buf_bcnt	;		//buffered data byte cnt, cnt from 1
reg	signed [3:0]	nxt_buf_bcnt;
wire						buf_4b			;		//has buffered more than 4 bytes
reg			[2:0]		sub_bcnt		;
reg			[7:0]		wd0, wd1, wd2, wd3;	//data map to dma_wdata
reg			[7:0]		ed0, ed1, ed2;			//data buffered for next data beat
wire						dma_wd_last	;
wire						last_beat_vld;

assign	buf_4b			= (!buf_bcnt[3]) & buf_bcnt[2];
assign	buf_rd			= ((!buf_4b) | send_a_data) & (!buf_empty) & (!remain_bnum_rd[16]);

assign	dma_wd_last	= (remain_bnum_send[15:2] == 'd0)? 1'b1 : 1'b0;
assign	last_beat_vld = dma_wd_last & (buf_bcnt[1:0] > remain_bnum_send[1:0]) & (!buf_bcnt[3]);
assign	dma_w_dvld	= buf_4b | last_beat_vld;
assign	dma_wdata		= {wd3, wd2, wd1, wd0};

always @(*) begin
		if(fir_wdata)
				dma_wbe = fir_wbe;
		else if(dma_wd_last)
				dma_wbe = last_wbe;
		else
				dma_wbe = 4'b1111;
end

always @(*) begin
		if(fir_wdata) begin
				case(align_mode)
				'd0:		sub_bcnt = 'd4;
				'd1:		sub_bcnt = 'd3;
				'd2:		sub_bcnt = 'd2;
				'd3:		sub_bcnt = 'd1;
				endcase
		end else begin
				sub_bcnt = 'd4;
		end
end

always @(*) begin
		case({buf_rd, send_a_data})
		2'b00:	nxt_buf_bcnt = buf_bcnt;
		2'b01:	nxt_buf_bcnt = buf_bcnt - {1'b0, sub_bcnt};
		2'b10:	nxt_buf_bcnt = buf_bcnt	+ 'sd4;
		2'b11:	nxt_buf_bcnt = buf_bcnt - {1'b0, sub_bcnt} + 'sd4;
		endcase
end

always @(posedge clk or negedge rstn)
if(!rstn)
		buf_bcnt		<= 'd0;
else if(send_a_cmd)
		buf_bcnt		<= 'd0;
else if(buf_rd || send_a_data)
		buf_bcnt		<= nxt_buf_bcnt;
		
always @(posedge clk)		// or negedge rstn)
if(buf_rd || (send_a_data && remain_bnum_rd[16])) begin
		case(align_mode)
		'd0: begin
				wd0 <= buf_rdata[0*8 +: 8];
				wd1	<= buf_rdata[1*8 +: 8];
				wd2 <= buf_rdata[2*8 +: 8];
				wd3 <= buf_rdata[3*8 +: 8];
				
				ed0 <= ed0;
				ed1 <= ed1;
				ed2 <= ed2;
		end
		
		'd1: begin
				wd0	<= ed0;
				wd1	<= buf_rdata[0*8 +: 8];
				wd2	<= buf_rdata[1*8 +: 8];
				wd3	<= buf_rdata[2*8 +: 8];
				
				ed0	<= buf_rdata[3*8 +: 8];
				ed1	<= ed1;
				ed2	<= ed2;
		end
		
		'd2: begin
				wd0	<= ed0;
				wd1	<= ed1;
				wd2	<= buf_rdata[0*8 +: 8];
				wd3	<= buf_rdata[1*8 +: 8];
				
				ed0	<= buf_rdata[2*8 +: 8];
				ed1	<= buf_rdata[3*8 +: 8];
				ed2	<= ed2;
		end
		 
		'd3: begin
				wd0	<= ed0;
				wd1	<= ed1;
				wd2	<= ed2;
				wd3	<= buf_rdata[0*8 +: 8];
				
				ed0	<= buf_rdata[1*8 +: 8];
				ed1	<= buf_rdata[2*8 +: 8];
				ed2	<= buf_rdata[3*8 +: 8];
		end
		endcase
end

endmodule