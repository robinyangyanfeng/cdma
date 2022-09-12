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
// File name    : tb.v
// Author       : sky@SiliconThink
// Email        : 
// Project      :
// Created      : 
// Copyright    : 
//
// Description  : 
// 1: 
//----------------------------------------------------------------------------//



`timescale 1ns / 10ps

module tb();

parameter	clk_cyc = 10.0;


reg     [7:0]   sys_mem [0 : (32*1024*1024 - 1)];   //32MB
reg     [7:0]   ref_mem [0 : (32*1024*1024 - 1)];   //32MB


reg             clk, rstn   ;

always #(clk_cyc/2.0) clk = ~clk;

initial begin

    $fsdbDumpfile("tb.fsdb");
    $fsdbDumpvars(0,tb);

	clk = 0; rstn = 1;
	repeat(10) @(posedge clk); rstn = 0;
	repeat(10) @(posedge clk); rstn = 1;
end


//--- connection model and DUT

//--- APB configure inf
wire			psel		;
wire			penable		;
wire	[31:0]	paddr		;	//byte addr
wire			pwrite		;
wire	[31:0]	pwdata		;
wire			pready		;
wire	[31:0]	prdata		;

wire    [3:0]   awid        ;
wire    [31:0]  awaddr      ;
wire    [7:0]   awlen       ;
wire    [2:0]   awsize      ;
wire    [1:0]   awburst     ;
wire    [1:0]   awlock      ;
wire    [3:0]   awcache     ;
wire    [2:0]   awprot      ;
wire            awvalid     ;
wire            awready     ;

wire    [3:0]   wid         ;
wire    [31:0]  wdata       ;
wire    [3:0]   wstrb       ;
wire            wlast       ;
wire            wvalid      ;
wire            wready      ;
wire    [3:0]   bid         ;
wire    [1:0]   bresp       ;
wire            bvalid      ;
wire            bready      ;

wire    [3:0]   arid        ;
wire    [31:0]  araddr      ;
wire    [7:0]   arlen       ;
wire    [2:0]   arsize      ;
wire    [1:0]   arburst     ;
wire    [1:0]   arlock      ;
wire    [3:0]   arcache     ;
wire    [2:0]   arprot      ;
wire            arvalid     ;
wire            arready     ;

wire    [3:0]   rid         ;
wire    [31:0]  rdata       ;
wire    [1:0]   rresp       ;
wire            rlast       ;
wire            rvalid      ;
wire            rready      ;

wire            intr        ;


assign  arlen[7:4]  = 'd0;
assign  awlen[7:4]  = 'd0;

apb_ms_model    u_apb_ms_model(
	//--- APB configure inf
	.psel			(psel			),
	.penable		(penable		),
	.paddr			(paddr			),
	.pwrite			(pwrite			),
	.pwdata			(pwdata			),
	.pready			(pready			),
	.prdata			(prdata			),

    .intr           (intr           ),
                                    
    .clk			(clk			),
    .rstn			(rstn			) 
);

axi32_slave_model u_axi32_slave_model(
    .aclk           (clk            ),
    .arstn          (rstn           ),
    .awid           (awid           ),
    .awaddr         (awaddr         ),
    .awlen          (awlen          ),
    .awsize         (awsize         ),
    .awburst        (awburst        ),
    .awlock         (awlock         ),
    .awcache        (awcache        ),
    .awprot         (awprot         ),
    .awvalid        (awvalid        ),
    .awready        (awready        ),
                                    
    .wid            (wid            ),
    .wdata          (wdata          ),
    .wstrb          (wstrb          ),
    .wlast          (wlast          ),
    .wvalid         (wvalid         ),
    .wready         (wready         ),
    .bid            (bid            ),
    .bresp          (bresp          ),
    .bvalid         (bvalid         ),
    .bready         (bready         ),
                                    
    .arid           (arid           ),
    .araddr         (araddr         ),
    .arlen          (arlen          ),
    .arsize         (arsize         ),
    .arburst        (arburst        ),
    .arlock         (arlock         ),
    .arcache        (arcache        ),
    .arprot         (arprot         ),
    .arvalid        (arvalid        ),
    .arready        (arready        ),
                                    
    .rid            (rid            ),
    .rdata          (rdata          ),
    .rresp          (rresp          ),
    .rlast          (rlast          ),
    .rvalid         (rvalid         ),
    .rready         (rready         ) 
);


cdma u_cdma(
	//--- APB configure inf
	.psel			(psel			),
	.penable		(penable		),
	.paddr			(paddr[7:0]     ),
	.pwrite			(pwrite			),
	.pwdata			(pwdata			),
	.pready			(pready			),
	.prdata			(prdata			),

    //--- AXI inf
	.arid          	(arid          	),
	.araddr        	(araddr        	),
	.arlen         	(arlen[3:0]     ),
	.arsize        	(arsize        	),
	.arburst       	(arburst       	),
	.arlock        	(arlock        	),
	.arcache       	(arcache       	),
	.arprot        	(arprot        	),
	.arvalid       	(arvalid       	),
	.arready       	(arready       	),
	                                
	.rid           	(rid           	),
	.rdata         	(rdata         	),
	.rresp         	(rresp         	),
	.rlast         	(rlast         	),
	.rvalid        	(rvalid        	),
	.rready        	(rready        	),
                                    
	.awid			(awid			),
	.awaddr        	(awaddr        	),
	.awlen         	(awlen[3:0]     ),
	.awsize        	(awsize        	),
	.awburst       	(awburst       	),
	.awlock        	(awlock        	),
	.awcache       	(awcache       	),
	.awprot        	(awprot        	),
	.awvalid       	(awvalid       	),
	.awready       	(awready       	),
                                    
	.wid           	(wid           	),
	.wdata         	(wdata         	),
	.wstrb         	(wstrb         	),
	.wlast         	(wlast         	),
	.wvalid        	(wvalid        	),
	.wready        	(wready        	),
	.bid           	(bid           	),
	.bresp         	(bresp         	),
	.bvalid        	(bvalid        	),
	.bready        	(bready        	),
                                    
    .intr           (intr           ),
                                    
    .clk            (clk            ),
    .rstn           (rstn           ) 
);



endmodule

