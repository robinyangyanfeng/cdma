//-----------------------------------------------------//
// File name		:	cdma_fetch.v
// Author				:	Yangyf
// E-mail				:
// Project			:
// Created			:
// Description	:
//	1:	Fetch	linked list cmd for next DMA command.
//-----------------------------------------------------//

module	cmd_fetch(
		//---	cmd	linked list req and ack
		ll_req					,
		ll_addr					,
		ll_ack					,
		ll_dvld					,
		ll_rdata				,
		ll_dcnt					,
		
		//---	DMA inf
		dma_r_req				,
		dma_r_ack				,
		dma_r_addr			,
		dma_r_len				,
		
		dma_dvld				,
		dma_rd_last			,
		dma_rdata				,
		dma_rbe					,
		dma_dack				,
		
		clk							,
		rstn
);

input		wire						clk,	rstn			;

//---	cmd linked list request and ack
input		wire						ll_req					;		//linked list request, high level active
input		wire		[31:0]	ll_addr					;		//32bit aligned address
output	wire						ll_ack					;		//
output	wire						ll_dvld					;		//linked list	data valid
output	wire		[31:0]	ll_rdata				;		//linked list read data
output	wire		[2:0]		ll_dcnt					;		//linked list read data cnt: 0~7

//--- DMA inf
output	wire						dma_r_req				;		//1: send out dma req
input		wire						dma_r_ack				;
output	wire		[31:0]	dma_r_addr			;		//byte addr, may not 32bit align
output	wire		[15:0]	dma_r_len				;		//bytes length, cnt from 0

input		wire						dma_dvld				;		//read data valid
input		wire						dma_rd_last			;		//1'b1: last data of a dma_r_req
input		wire		[31:0]	dma_rdata				;
input		wire		[3:0]		dma_rbe					;		//read data byte valid
output	wire						dma_dack				;


assign	dma_r_req		=	ll_req;
assign	dma_r_addr	=	ll_addr;
assign	dma_r_len		=	4*6	-	1;
assign	dma_dack		=	1'b1;

assign	ll_ack			=	dma_r_ack;
assign	ll_dvld			=	dma_dvld;
assign	ll_rdata		=	dma_rdata;


always	@(posedge	clk or negedge rstn)
if(~rstn)
		ll_dcnt	<=	'd0;
else	if(ll_req	&& ll_ack)
		ll_dcnt	<=	'd0;
else	if(ll_dvld)
		ll_dcnt	<=	ll_dcnt	+	'd1;
		
endmodule