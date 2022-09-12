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
// File name    : apb_ms_model.v
// Author       : sky@SiliconThink
// Email        : 
// Project      :
// Created      : 
// Copyright    : 
//
// Description  : 
// 1: APB master inf model.
//----------------------------------------------------------------------------//

`include "cdma_sim_def.v"

module apb_ms_model(
	//--- APB configure inf
	psel			,
	penable			,
	paddr			,
	pwrite			,
	pwdata			,
	pready			,
	prdata			,

    intr            ,

    clk				,
    rstn			 
);

parameter   BASE_16MB = 16*1024*1024;
parameter   DMA_CFG_BASE = 'd0;
parameter   LLR_BASE  = 15*1024*1024 + (512 + 128)*1024;


input   wire			clk, rstn		;


//--- APB configure inf
output	reg				psel			;
output	reg				penable			;
output	reg		[31:0]	paddr			;	//byte addr
output	reg				pwrite			;
output	reg		[31:0]	pwdata			;
input	wire			pready			;
input	wire	[31:0]	prdata			;

input   wire            intr            ;

//--- 1: apb w/r task

task apb_write;
input	[31:0]	addr	;
input	[31:0]	wdata	;
begin
	@(posedge clk); #1;
	psel = 1; pwrite = 1; paddr = addr; pwdata = wdata;
	@(posedge clk); #1;
	penable = 1;
	
	@(negedge clk);
	while(!pready) begin
		@(negedge clk);
	end

	@(posedge clk); #1;
	psel = 0; penable = 0;
end
endtask

task apb_read;
input	[31:0]	addr	;
output	[31:0]	rdata	;
begin	
	@(posedge clk); #1;
	psel = 1; pwrite = 0; paddr = addr;
	@(posedge clk); #1;
	penable = 1;
	
	@(negedge clk);
	while(!pready) begin
		@(negedge clk);
	end
	rdata = prdata;

	@(posedge clk); #1;
	psel = 0; penable = 0;
end
endtask


//--- 2: DMA cfg initial ctrl ---//
reg     [31:0]  sar         ;
reg     [31:0]  dar         ;
reg     [15:0]  xsize       ;   //cnt from 0
reg     [15:0]  ysize       ;   //cnt from 0
reg     [15:0]  sa_ystep    ;   //cnt from 1
reg     [15:0]  da_ystep    ;   //cnt from 1
reg     [31:0]  llr         ;   //link list reg
reg     [31:0]  nxt_llr     ;
reg             bf          ;   //bufferable flag
reg             cf          ;   //cacheable flag

reg     [19:0]  sa_4k_base  ;
reg     [19:0]  da_4k_base  ;
reg     [31:0]  xcnt, ycnt  ;
reg     [7:0]   rand_b0, rand_b1;
reg     [31:0]  rand0, rand1;
reg     [31:0]  cfg_rdata   ;

reg     [31:0]  cmd_mem[0:1023];//maximal store 170 DMA commands
reg     [15:0]  cmd_addr    ;
reg     [15:0]  cmd_raddr   ;
reg signed  [15:0]  cmd_goon;


reg     [15:0]  xloop, yloop;
reg     [31:0]  org_addr    ;
reg     [31:0]  des_addr    ;
reg     [7:0]   org_byte    ;
reg     [7:0]   cmd_num     ;   //2D DMA cmd number
reg     [31:0]  llr_addr    ;

reg     [3:0]   test_case   ;

//--- Addr space:
//--- 1: 0~15.5MB:  source data mem
//--- 2: 15.5~16MB: linked list
//--- 3: 16~32MB: destination data mem

task    mem_chk;
input   [31:0]  start_addr  ;
input   [31:0]  len         ;   //cnt from 1
reg     [31:0]  xcnt        ;
reg     [31:0]  addr        ;
begin
    for(xcnt=0; xcnt<len; xcnt=xcnt+1) begin
        addr    = start_addr + xcnt;

        if(`SYS_MEM_PATH[addr] !== `REF_MEM_PATH[addr]) begin
            $display("Error: Memory content check error: addr: %8x, data in sys_mem is %2x, should be %2x.", addr, `SYS_MEM_PATH[addr], `REF_MEM_PATH[addr]);
            repeat(2) @(posedge clk); #1;
            $finish();
        end
    end
end

endtask

task    dma_apb_cfg;
input   [15:0]  cmd_raddr;
begin
    apb_write((DMA_CFG_BASE + 0*4), cmd_mem[cmd_raddr + 0]);
    apb_write((DMA_CFG_BASE + 1*4), cmd_mem[cmd_raddr + 1]);
    apb_write((DMA_CFG_BASE + 2*4), cmd_mem[cmd_raddr + 2]);
    apb_write((DMA_CFG_BASE + 3*4), cmd_mem[cmd_raddr + 3]);
    apb_write((DMA_CFG_BASE + 4*4), cmd_mem[cmd_raddr + 4]);
    apb_write((DMA_CFG_BASE + 5*4), cmd_mem[cmd_raddr + 5]);
    apb_write((DMA_CFG_BASE + 7*4), {22'h0, cf, bf, 3'h0, 1'b0, 3'h0, 1'b1});
end
endtask

task    dma_mem_cfg;
input   [31:0]  llr_addr    ;
input   [15:0]  cmd_raddr   ;

reg     [7:0]   y, x        ;
reg     [31:0]  cmd         ;
reg     [31:0]  addr        ;
begin
    addr = llr_addr;
    for(y=0; y<6; y=y+1) begin
        cmd = cmd_mem[cmd_raddr + y];
        `SYS_MEM_PATH[addr + 0] = cmd[8*0 +: 8];
        `SYS_MEM_PATH[addr + 1] = cmd[8*1 +: 8];
        `SYS_MEM_PATH[addr + 2] = cmd[8*2 +: 8];
        `SYS_MEM_PATH[addr + 3] = cmd[8*3 +: 8];

        addr = addr + 4;
    end
end
endtask

initial begin

	psel		= 0;
	penable		= 0;
	paddr		= 0;
	pwrite		= 0;
	pwdata		= 0;
    #10;

	@(posedge rstn);
    repeat(10) @(posedge clk);

    //--- 1: initial sys_mem 
    for(xcnt=0; xcnt<(BASE_16MB); xcnt=xcnt+1) begin
        rand_b0 = $random();
        `SYS_MEM_PATH[xcnt] = rand_b0;
        `REF_MEM_PATH[xcnt] = rand_b0;
    end

    //--- 2: single DMA cmd test(loop all sa/da/xsize byte locations, check cross 4KB boundary) 
    test_case = 0;
    llr = 0; bf = 0; cf = 0;

    `ifdef SIMPLE_CASE0
    for(ycnt=(4096-6); ycnt<=(4096+6); ycnt=ycnt+1) begin //base offset
        $display($time, "\tInfo: DMA test for source begin addr offet: %4x.", ycnt);
        for(xcnt=3; xcnt<=16; xcnt=xcnt+1) begin            //burst length byte
    `else
    for(ycnt=(4096-16); ycnt<=(4096+16); ycnt=ycnt+1) begin //base offset
        $display($time, "\tInfo: DMA test for source begin addr offet: %4x.", ycnt);
        for(xcnt=3; xcnt<=66; xcnt=xcnt+1) begin            //burst length byte
    `endif
            //--- generate DMA info
            `ifndef SMALL_SPACE
            sa_4k_base = ( $unsigned($random()) % (15*1024*1024)) >> 12;
            da_4k_base = ( ($unsigned($random()) % (15*1024*1024)) + BASE_16MB) >> 12;
            `else
            sa_4k_base = ( $unsigned($random()) % (512*1024)) >> 12;
            da_4k_base = ( ($unsigned($random()) % (512*1024)) + BASE_16MB) >> 12;
            `endif

            xsize   = xcnt; 
            ysize   = $unsigned($random()) % 4;

            if(xcnt < 6) begin
                sa_ystep   = 1023;
                da_ystep   = 1020;
            end else if(xcnt <12) begin
                sa_ystep   = 1022;
                da_ystep   = 1021;
            end else if(xcnt <18) begin
                sa_ystep   = 1021;
                da_ystep   = 1022;
            end else begin
                sa_ystep   = 1020;
                da_ystep   = 1023;
            end

    
            sar = (sa_4k_base << 12) + ycnt;
            dar = (da_4k_base << 12) + (4096+8 - ycnt);


            //copy DMA info to cmd_mem
            cmd_addr = 0; cmd_raddr = 0;
            cmd_mem[cmd_addr] = sar;    cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = dar;    cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = xsize;  cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = ysize;  cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = {da_ystep, sa_ystep}; cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = llr; cmd_addr = cmd_addr + 1;


            //write DMA info to cfg_reg or linked list mem
            cmd_goon = 1;
            while(cmd_goon != 0) begin
                if(cmd_goon == 1) begin
                    dma_apb_cfg(0);
                end else begin

                end

                nxt_llr = cmd_mem[cmd_raddr + 5];
                if(nxt_llr == 'd0) begin
                    cmd_goon = 0;
                end else begin
                    cmd_goon = 1;
                end

                //--- copy data to ref_mem
                org_addr = sar; des_addr = dar;
                for(yloop=0; yloop<= ysize; yloop=yloop+1) begin
                    for(xloop=0; xloop<=xsize; xloop=xloop+1) begin
                        org_byte = `SYS_MEM_PATH[org_addr];
                        `REF_MEM_PATH[des_addr] = org_byte;
                            
                        org_addr = org_addr + 1; des_addr = des_addr + 1;
                    end
                    org_addr = org_addr + sa_ystep;
                    des_addr = des_addr + da_ystep;
                end
            end //while(cmd_goon != 0)
            
            //DMA start
            apb_write((DMA_CFG_BASE + 8*4), 1);

            //wait DMA end
            @(posedge intr);
            apb_read((DMA_CFG_BASE + 6*4), cfg_rdata);
            if(cfg_rdata[4] == 1) begin
                $display("Error: DMA internal buffer error.");
                repeat(2) @(posedge clk); #1;
                $finish();
            end

            if(cfg_rdata[15:8] != 1) begin
                $display("Error: DMA total command number error: data read out is %4x, should be %4x.", cfg_rdata[15:8], 1);
                repeat(2) @(posedge clk); #1;
                $finish();
            end


            if(cfg_rdata[1] == 1) begin
                $display("Error: DMA is still busy.");
                repeat(2) @(posedge clk); #1;
                $finish();
            end

            if(cfg_rdata[0] != 1) begin
                $display("Error: DMA's end_flag doesn't go high.");
                repeat(2) @(posedge clk); #1;
                $finish();
            end

            //clear intr
            apb_write((DMA_CFG_BASE + 6*4), 0);

            //MEM content check
            repeat(50)  @(posedge clk); #1;
    
            `ifndef SMALL_SPACE
            mem_chk(BASE_16MB, BASE_16MB);
            `else
            mem_chk(BASE_16MB, (1*1024*1024));
            `endif
        end
    end

    repeat(200) @(posedge clk);

    //--- 3: Linked list multi-DMA test
    test_case = 1;
    cmd_num = 0;
    for(ycnt=0; ycnt< `MAX_RAND_TEST; ycnt=ycnt+1) begin //test case loop
        cmd_num =  $unsigned($random()) % 4;

        $display($time, "\tInfo: %4dst DMA test for multiple 2D DMA cmd linked list, total 2D DMA cmd number is: %2d.", ycnt, (cmd_num+1));

        if(cmd_num == 0)
            llr = 0;
        else
            llr = LLR_BASE;

        for(xcnt=0; xcnt<=cmd_num; xcnt=xcnt+1) begin   //2D cmd loop
            //--- generate DMA info
            `ifndef SMALL_SPACE
            sa_4k_base = ( $unsigned($random()) % (15*1024*1024)) >> 12;
            da_4k_base = ( ($unsigned($random()) % (15*1024*1024)) + BASE_16MB) >> 12;
            `else
            sa_4k_base = ( $unsigned($random()) % (512*1024)) >> 12;
            da_4k_base = ( ($unsigned($random()) % (512*1024)) + BASE_16MB) >> 12;
            `endif

            //this configure will access maximal 2MB space 
            xsize   = $unsigned($random()) % (64*1024);
            ysize   = $unsigned($random()) % 16;
            sa_ystep= $unsigned($random()) % (16*1024);
            da_ystep= $unsigned($random()) % (16*1024);
            
            //offset within 4KB
            rand0   = $unsigned($random()) % (4*1024);
            rand1   = $unsigned($random()) % (4*1024);

            sar = (sa_4k_base << 12) + rand0;
            dar = (da_4k_base << 12) + rand1;

            //copy DMA info to cmd_mem
            cmd_addr = 0; cmd_raddr = 0;
            cmd_mem[cmd_addr] = sar;    cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = dar;    cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = xsize;  cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = ysize;  cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = {da_ystep, sa_ystep}; cmd_addr = cmd_addr + 1;
            cmd_mem[cmd_addr] = llr; cmd_addr = cmd_addr + 1;

            if(xcnt == 0) begin //first 2D DMA cmd
                dma_apb_cfg(0);
                @(posedge clk);
            end else begin      //2nd, 3rd, ... DMA cmd
                dma_mem_cfg((LLR_BASE + (6*4*(xcnt-1))), 0);
                @(posedge clk);
            end

            if((xcnt + 1) == cmd_num)
                llr = 0;
            else
                llr = llr + 6*4;

            //--- copy data to ref_mem
            org_addr = sar; des_addr = dar;
            for(yloop=0; yloop<= ysize; yloop=yloop+1) begin
                for(xloop=0; xloop<=xsize; xloop=xloop+1) begin
                    org_byte = `SYS_MEM_PATH[org_addr];
                    `REF_MEM_PATH[des_addr] = org_byte;
                        
                    org_addr = org_addr + 1; des_addr = des_addr + 1;
                end
                org_addr = org_addr + sa_ystep;
                des_addr = des_addr + da_ystep;
            end
        end //for(xcnt=0; xcnt<=cmd_num; xcnt=xcnt+1)   //2D cmd loop

        //DMA start
        apb_write((DMA_CFG_BASE + 8*4), 1);

        //wait DMA end
        @(posedge intr);
        apb_read((DMA_CFG_BASE + 6*4), cfg_rdata);
        if(cfg_rdata[4] == 1) begin
            $display("Error: DMA internal buffer error.");
            repeat(2) @(posedge clk); #1;
            $finish();
        end

        if(cfg_rdata[15:8] != (cmd_num + 1)) begin
            $display("Error: DMA total command number error: data read out is %2x, should be %2x.", cfg_rdata[15:8], (cmd_num + 1));
            repeat(2) @(posedge clk); #1;
            $finish();
        end


        if(cfg_rdata[1] == 1) begin
            $display("Error: DMA is still busy.");
            repeat(2) @(posedge clk); #1;
            $finish();
        end

        if(cfg_rdata[0] != 1) begin
            $display("Error: DMA's end_flag doesn't go high.");
            repeat(2) @(posedge clk); #1;
            $finish();
        end

        //clear intr
        apb_write((DMA_CFG_BASE + 6*4), 0);

        //MEM content check
        repeat(50)  @(posedge clk); #1;
    
        `ifndef SMALL_SPACE
        mem_chk(BASE_16MB, BASE_16MB);
        `else
        mem_chk(BASE_16MB, (2*1024*1024));
        `endif

        
    end //for(ycnt=0; ycnt< MAX_RAND_TEST; ycnt=ycnt+1) //test case loop


    repeat(10) @(posedge clk); #1;
    $display("OK: sim pass.");
    $finish();

end

endmodule

