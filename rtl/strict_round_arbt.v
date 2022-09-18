//-------------------------------------------//
// File name			: strict_round_arbt.v
// Author					: Yangyf
// Email					:
// Project				:
// Created				:
// Copyright			:
// Description		:
// 1: gnt? is 1T delay of req?;
// 2: do arbitration every 2 cycles;
//-------------------------------------------//

module	strict_round_arbt (
		req0		,
		req1		,
		req2		,
		req3		,
		
		gnt0		,
		gnt1		,
		gnt2		,
		gnt3		,
		gnt_id	,
		
		clk			,
		rstn
);

//----- parameter -----//



//----- input/output ports-----//
input		wire							req0, req1, req2, req3;
output	reg								gnt0, gnt1, gnt2, gnt3;
output	reg			[1:0]			gnt_id;
input		wire							clk, rstn;

wire						arbt_time		;
reg							arbt_time_d	;		//do arbitor at every 2 cycles, as we use registered gnt
reg			[7:0]		cur_pri			;		//bit[1:0]: highest priority ID; bit[7:6]: lowest priority ID
reg			[1:0]		gnt_id_w		;		//0~3: real win request ID
reg			[1:0]		gnt_id_fix	;		//0~3: win ID at fixed arbt stage

reg							fix_req0		;
reg							fix_req1		;
reg							fix_req2		;
reg							fix_req3		;

assign	arbt_time		=	(!arbt_time_d) & (req0 | req1 | req2 | req3);

always @(*) begin
		case(cur_pri[1:0])
		'd0:		fix_req0 = req0;
		'd1:		fix_req0 = req1;
		'd2:		fix_req0 = req2;
		'd3:		fix_req0 = req3;
		endcase
end

always @(*) begin
		case(cur_pri[3:2])
		'd0:		fix_req1 = req0;
		'd1:		fix_req1 = req1;
		'd2:		fix_req1 = req2;
		'd3:		fix_req1 = req3;
		endcase
end

always @(*) begin
		case(cur_pri[5:4])
		'd0:		fix_req2 = req0;
		'd1:		fix_req2 = req1;
		'd2:		fix_req2 = req2;
		'd3:		fix_req2 = req3;
		endcase
end

always @(*) begin
		case(cur_pri[7:6])
		'd0:		fix_req3 = req0;
		'd1:		fix_req3 = req1;
		'd2:		fix_req3 = req2;
		'd3:		fix_req3 = req3;
		endcase
end

always @(*) begin
		if(fix_req0)
				gnt_id_fix	= 'd0;
		else if(fix_req1)
				gnt_id_fix	= 'd1;
		else if(fix_req2)
				gnt_id_fix	= 'd2;
		else
				gnt_id_fix	= 'd3;
end

always @(*) begin
		case(gnt_id_fix)
		'd0:		gnt_id_w		= cur_pri[1:0];
		'd1:		gnt_id_w		= cur_pri[3:2];
		'd2:		gnt_id_w		= cur_pri[5:4];
		'd3:		gnt_id_w		= cur_pri[7:6];
		endcase
end

always @(posedge clk or negedge rstn)
if(!rstn) begin
		gnt0		<= 'd0;
		gnt1		<= 'd0;
		gnt2		<= 'd0;
		gnt3		<= 'd0;
end else if(arbt_time) begin
		if(gnt_id_w == 'd0)
				gnt0		<= 1'b1;
		
		if(gnt_id_w == 'd1)
				gnt1		<= 1'b1;
				
		if(gnt_id_w == 'd2)
				gnt2		<= 1'b1;
				
		if(gnt_id_w == 'd3)
				gnt3		<= 1'b1;
end else if(arbt_time_d) begin
		gnt0		<= 'd0;
		gnt1		<= 'd0;
		gnt2		<= 'd0;
		gnt3		<= 'd0;
end

always @(posedge clk or negedge rstn)
if(!rstn)
		gnt_id	<= 'd0;
else if(arbt_time)
		gnt_id	<= gnt_id_w;
		
always @(posedge clk or negedge rstn)
if(!rstn)
		cur_pri <= {2'd3, 2'd2, 2'd1, 2'd0};			//must assign fifferent value to each section
else if(arbt_time) begin
		case(gnt_id_fix)
		'd0:		cur_pri <= {cur_pri[1:0], cur_pri[7:2]};
		'd1:		cur_pri	<= {cur_pri[3:2], cur_pri[7:4], cur_pri[1:0]};
		'd2:		cur_pri	<= {cur_pri[5:4], cur_pri[7:6], cur_pri[3:0]};
		'd3:		cur_pri <= {cur_pri[7:6], cur_pri[5:0]};		//actually no change
		endcase
end

always @(posedge clk or negedge rstn)
if(!rstn)
		arbt_time_d	<= 'd0;
else
		arbt_time_d	<= arbt_time;

endmodule