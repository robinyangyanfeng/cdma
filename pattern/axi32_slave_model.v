// ---------------------------------------------------------------------------//
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from SiliconThink.
//
//      (C) COPYRIGHT SiliconThink Limited or its affiliates
//                   ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from SiliconThink or its affiliates.
// ---------------------------------------------------------------------------//

//----------------------------------------------------------------------------//
// File name    : .v
// Author       : sky@SiliconThink 
// E-mail       : 
// Project      : 
// Created      : 
// Copyright    : 
// Description  :                                       
//  1: Read cmd support outstanding support. 
//                                              
//---------------------------------------------------------------------------//

`include "cdma_sim_def.v"

module axi32_slave_model (
    aclk        ,
    arstn       ,
    awid        ,
    awaddr      ,
    awlen       ,
    awsize      ,
    awburst     ,
    awlock      ,
    awcache     ,
    awprot      ,
    awvalid     ,
    awready     ,
    
    wid         ,
    wdata       ,
    wstrb       ,
    wlast       ,
    wvalid      ,
    wready      ,
    bid         ,
    bresp       ,
    bvalid      ,
    bready      ,
    
    
    arid        ,
    araddr      ,
    arlen       ,
    arsize      ,
    arburst     ,
    arlock      ,
    arcache     ,
    arprot      ,
    arvalid     ,
    arready     ,
    
    rid         ,
    rdata       ,
    rresp       ,
    rlast       ,
    rvalid      ,
    rready       

);

//----- parameters -----//

parameter   RCMD_OS    = 16;


input   wire            aclk        ;
input   wire            arstn       ;
input   wire    [3:0]   awid        ;
input   wire    [31:0]  awaddr      ;
input   wire    [7:0]   awlen       ;
input   wire    [2:0]   awsize      ;
input   wire    [1:0]   awburst     ;
input   wire    [1:0]   awlock      ;
input   wire    [3:0]   awcache     ;
input   wire    [2:0]   awprot      ;
input   wire            awvalid     ;
output  reg             awready     ;

input   wire    [3:0]   wid         ;
input   wire    [31:0]  wdata       ;
input   wire    [3:0]   wstrb       ;
input   wire            wlast       ;
input   wire            wvalid      ;
output  reg             wready      ;
output  reg     [3:0]   bid         ;
output  reg     [1:0]   bresp       ;
output  reg             bvalid      ;
input   wire            bready      ;


input   wire    [3:0]   arid        ;
input   wire    [31:0]  araddr      ;
input   wire    [7:0]   arlen       ;
input   wire    [2:0]   arsize      ;
input   wire    [1:0]   arburst     ;
input   wire    [1:0]   arlock      ;
input   wire    [3:0]   arcache     ;
input   wire    [2:0]   arprot      ;
input   wire            arvalid     ;
output  reg             arready     ;

output  reg     [3:0]   rid         ;
output  reg     [31:0]  rdata       ;
output  reg     [1:0]   rresp       ;
output  reg             rlast       ;
output  reg             rvalid      ;
input   wire            rready      ;



//----- internal variables -----//

//--- 1: axi write transfer ---//
reg     [15:0]  wcmd_wait   ;
reg     [15:0]  wdata_wait  ;
reg     [15:0]  wresp_wait  ;
reg     [6:0]   wcmd_cyc    ;
reg     [3:0]   wdata_cyc   ;
reg     [2:0]   wresp_cyc   ;
reg     [8:0]   wlen        ;
reg     [31:0]  waddr       ;

`ifdef EN_AXI_LATENCY
always @(*) begin
    if(wcmd_wait <=63)
        wcmd_cyc = 0;
    else if(wcmd_wait <= 95)
        wcmd_cyc = 1;
    else if(wcmd_wait <= 111)
        wcmd_cyc = 2;
    else if(wcmd_wait <= 115)
        wcmd_cyc = 3;
    else
        wcmd_cyc = $unsigned($random()) % 32;
end

always @(*) begin
    if(wdata_wait <=23)
        wdata_cyc = 0;
    else if(wdata_wait <= 27)
        wdata_cyc = 1;
    else if(wdata_wait <= 29)
        wdata_cyc = 2;
    else
        wdata_cyc = $unsigned($random()) % 8;
end

always @(*) begin
    if(wresp_wait <= 25)
        wresp_cyc = 0;
    else if(wresp_wait <= 29)
        wresp_cyc = 1;
    else
        wresp_cyc = $unsigned($random())%4;
end
`else 
always @(arstn) begin
    wcmd_cyc = 0;
    wdata_cyc = 0;
    wresp_cyc = 0;
end
`endif


initial begin
    awready = 1'b0;
    wready  = 1'b0;
    bid     = 'd0;
    bresp   = 'd0;
    bvalid  = 'd0;

    @(posedge arstn);

    @(posedge aclk);
    wcmd_wait   = $unsigned($random()) % 128;
    wdata_wait  = $unsigned($random()) % 32;
    wresp_wait  = $unsigned($random()) % 32;
    #1;

    @(negedge aclk);
    forever begin

        //--- receive cmd
        if(wcmd_cyc == 'd0) begin
            awready = 1'b1;
        end else begin
            awready = 1'b0;
        end
        
        while(awvalid == 1'b0) @(negedge aclk);
        bid     = awid;
        wlen    = awlen + 'd1;
        waddr   = awaddr;
        @(negedge aclk);

        if(wcmd_cyc != 'd0) begin
            repeat(wcmd_cyc - 1) @(negedge aclk);
            awready = 1'b1;
            @(negedge aclk);
        end
        
        awready = 1'b0;

        //--- receive wdata
        while(wlen != 'd0) begin
            if(wdata_cyc == 'd0) begin
                wready  = 1'b1;
            end else begin
                wready  = 1'b0;
                repeat(wdata_cyc) @(negedge aclk);
                wready  = 1'b1;
            end

            while(wvalid == 1'b0) @(negedge aclk);
            
            #0.2;
            if(wstrb[0])
                `SYS_MEM_PATH[waddr + 0] = wdata[8*0 +: 8];
            if(wstrb[1])
                `SYS_MEM_PATH[waddr + 1] = wdata[8*1 +: 8];
            if(wstrb[2])
                `SYS_MEM_PATH[waddr + 2] = wdata[8*2 +: 8];
            if(wstrb[3])
                `SYS_MEM_PATH[waddr + 3] = wdata[8*3 +: 8];


            @(negedge aclk);
            wready  = 1'b0;
            wdata_wait  = $unsigned($random()) % 32;
            wlen    = wlen - 1;
            waddr   = waddr + 4;
        end

        wcmd_wait   = $unsigned($random()) % 128;
        
        //--- generate resp
        repeat(wresp_cyc) @(negedge aclk);
        bvalid = 1'b1;
        while(bready == 1'b0) @(negedge aclk);
        @(negedge aclk);
        bvalid = 1'b0;
        wresp_wait  = $unsigned($random()) % 32;
        #1;
    end

end




//--- 2: axi read transfer ---//
reg     [15:0]  rcmd_wait   ;
reg     [15:0]  rdata_wait  ;
reg     [5:0]   dsend_wait  ;
reg     [6:0]   rcmd_cyc    ;
reg     [6:0]   rdata_cyc   ;
reg     [3:0]   dsend_cyc   ;
reg     [8:0]   rlen        ;
reg     [31:0]  raddr       ;

reg     [(32+8+4)-1 : 0] rcmd_buf [0: (RCMD_OS-1)];
reg     [9:0]   rcmd_rptr   ;
reg     [9:0]   rcmd_wptr   ;
reg     [9:0]   rcmd_num    ;


`ifdef EN_AXI_LATENCY
always @(*) begin
    if(rcmd_wait <=63)
        rcmd_cyc = 0;
    else if(rcmd_wait <= 95)
        rcmd_cyc = 1;
    else if(rcmd_wait <= 111)
        rcmd_cyc = 2;
    else if(rcmd_wait <= 115)
        rcmd_cyc = 3;
    else
        rcmd_cyc = $unsigned($random()) % 32;
end

always @(*) begin
    if(rdata_wait <=23)
        rdata_cyc = 1;
    else if(rdata_wait <= 27)
        rdata_cyc = 8;
    else if(rdata_wait <= 29)
        rdata_cyc = 32;
    else
        rdata_cyc = $unsigned($random()) % 8;
end


always @(*) begin
if(dsend_wait <= (64-3))
    dsend_cyc = 0;
else if(dsend_wait == 62)
    dsend_cyc = 1;
else
    dsend_cyc = 2;
end

`else

always @(arstn) begin
    rcmd_cyc    = 0;
    rdata_cyc   = 0;
    dsend_cyc   = 0;
end
`endif

//--- 2.1: read cmd part ---//

initial begin
    rcmd_rptr   = 0;
    rcmd_wptr   = 0;
    rcmd_num    = 0;
    arready     = 1'b0;

    #2; 
    @(posedge arstn);

    //--- cmd receive loop ---//
    @(negedge aclk);
    rcmd_wait   = $unsigned($random()) % 128;
    forever begin
        if(rcmd_num < (RCMD_OS-1)) begin
            repeat(rcmd_cyc) @(negedge aclk);
            arready = 1'b1;
        end else begin
            repeat(rcmd_cyc) @(negedge aclk);
        end

        while(arvalid == 1'b0) @(negedge aclk);
        
        rcmd_wait   = $unsigned($random()) % 128;
        @(negedge aclk); 
        arready = 1'b0;
    end
end

always @(posedge aclk) begin
if(arstn) begin
    if(arready && arvalid) begin
        rcmd_buf[rcmd_wptr] <= {arid, arlen, araddr};

        if(rcmd_wptr == (RCMD_OS - 1))
            rcmd_wptr = 0;
        else
            rcmd_wptr   <= rcmd_wptr + 1;
    end
end
end

always @(*) begin
    if(rcmd_wptr < rcmd_rptr)
        rcmd_num = RCMD_OS + rcmd_wptr - rcmd_rptr;
    else
        rcmd_num = rcmd_wptr - rcmd_rptr;
end


//--- 2.2: read data part ---//

reg     [(32+8+4)-1 : 0] pop_cmd;
reg             rd_go_next;


initial begin
    rid     = 'd0;
    rresp   = 'd0;
    
    rvalid  = 1'b0;
    rdata   = 'd0;
    rlast   = 1'b0;
    rd_go_next= 1'b0;

    @(posedge arstn);

    @(negedge aclk);
    rdata_wait  = $unsigned($random()) % 32;
    dsend_wait  = $unsigned($random()) % 32;
    #1;

    @(negedge aclk);
    forever begin
   
        if(rcmd_num != 0) begin
            //--- cmd group read latency
            repeat(rdata_cyc) @(negedge aclk); 

            while(rcmd_num != 0) begin  //serve all buffered cmd
                //--- pop-out cmd
                pop_cmd = rcmd_buf[rcmd_rptr];
                raddr   = pop_cmd[0 +: 32];
                rlen    = pop_cmd[32 +: 8] + 1;
                rid     = pop_cmd[40 +: 4];
                if(rcmd_rptr == (RCMD_OS - 1))
                    rcmd_rptr   = 0;
                else
                    rcmd_rptr   = rcmd_rptr + 1;

                //--- send rdata
                while(rlen != 'd0) begin
                    //$display ($time, "Test 0: dsend_cyc: %h", dsend_cyc);
                    if(dsend_cyc == 'd0) begin 
                        //$display ($time, "Test 1: dsend_cyc: %h", dsend_cyc);
                        rvalid  = 1'b1;
                        rdata[8*0 +: 8] = `SYS_MEM_PATH[raddr + 0];
                        rdata[8*1 +: 8] = `SYS_MEM_PATH[raddr + 1];
                        rdata[8*2 +: 8] = `SYS_MEM_PATH[raddr + 2];
                        rdata[8*3 +: 8] = `SYS_MEM_PATH[raddr + 3];
                        if(rlen == 1)   rlast = 1'b1;
                    end else begin
                        //$display ($time, "Test 2: dsend_cyc: %h", dsend_cyc);
                        rvalid  = 1'b0;
                        repeat(dsend_cyc) @(negedge aclk);
                        rvalid  = 1'b1;
                        rdata[8*0 +: 8] = `SYS_MEM_PATH[raddr + 0];
                        rdata[8*1 +: 8] = `SYS_MEM_PATH[raddr + 1];
                        rdata[8*2 +: 8] = `SYS_MEM_PATH[raddr + 2];
                        rdata[8*3 +: 8] = `SYS_MEM_PATH[raddr + 3];

                        if(rlen == 1)   rlast = 1'b1;
                    end

                    @(negedge aclk);
                    while(rd_go_next == 1'b0) @(negedge aclk);

                    rvalid  = 1'b0;
                    dsend_wait  = $unsigned($random()) % 32;
                    rlen = rlen - 1;
                    raddr = raddr + 4;      //just support incr burst
                end
                
                rlast = 0;                
            end //while(rcmd_num != 0)
        end else begin //if(rcmd_num != 0)
            //--- no buffered read cmd, just wait some cycle
            repeat(rdata_cyc) @(negedge aclk);
        end

        rdata_wait  = $unsigned($random()) % 32;
        @(negedge aclk);
    end //forever

end


always @(posedge aclk) 
if(rvalid && rready)
    rd_go_next  <= 1'b1;
else 
    rd_go_next  <= 1'b0;

endmodule

