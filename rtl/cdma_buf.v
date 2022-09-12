//--------------------------------------//
// File name		: cdma_buf.v
// Author				: Yangyf
// E-mail				:
// Project			:
// Created			:
// Copyright		:
// Description	:
//	1: This is a 32bx24depth buffer
//-------------------------------------//

module	cdma_buf(
		buf_wr					,
		buf_wdata				,
		buf_empty_word	,
		
		buf_rd					,
		buf_rdata				,
		buf_buf_word		,
		buf_empty				,
		
		clk							,
		rstn
);


input		wire						clk, rstn				;

input		wire						buf_wr					;
input		wire	[31:0]		buf_wdata				;
output	reg		[5:0]			buf_empty_word	;		//empty 32b space in the data fifo (data phase)

input		wire						buf_rd					;
output	wire	[31:0]		buf_rdata				;		//valid same cycle as buf_rd
output	reg		[5:0]			buf_buf_word		;		//buffered 32b space in the data fifo (data phase)
output	wire						buf_empty				;


reg			[31:0]	mem	[0:23]	;

reg			[5:0]		rptr, wptr	;

assign	buf_empty	=	(rptr == wptr)? 1'b1 : 1'b0;
assign	buf_rdata	= mem[rptr[4:0]];

always @(posedge clk or negedge	rstn)
if(~rstn)
		buf_buf_word	<=	'd0;
else if(buf_wr	||	buf_rd)	begin
		case({buf_wr, buf_rd})
		2'b00:	buf_buf_word	<=	buf_buf_word;
		2'b01:	buf_buf_word	<=	buf_buf_word	-	'd1;
		2'b10:	buf_buf_word	<=	buf_buf_word	+	'd1;
		2'b11:	buf_buf_word	<=	buf_buf_word;
		endcase
end

always @(posedge clk)	begin	//	or negedge rstn
if(buf_wr)
	mem[wptr[4:0]]		<=	buf_wdata;
end

always @(posedge clk or negedge	rstn)
if(~rstn)
		wptr		<=	'd0;
else if(buf_wr)	begin
		if(wptr[4:0] == 'd23)
				wptr		<=	{{~{wptr[5]}}, 5'h0};
		else
				wptr		<=	wptr + 'd1;
end

always @(posedge	clk	or negedge rstn)
if(~rstn)
		rptr		<=	'd0;
else if(buf_rd) begin
		if(rptr[4:0] == 'd23)
				rptr		<= {{~{rptr[5]}}, 5'h0};
		else
				rptr		<= rptr + 'd1;
end

endmodule