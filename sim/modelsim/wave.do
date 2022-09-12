onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider tb
add wave -noupdate /tb/u_apb_ms_model/ycnt
add wave -noupdate /tb/u_apb_ms_model/xcnt
add wave -noupdate /tb/u_apb_ms_model/xsize
add wave -noupdate /tb/u_apb_ms_model/ysize
add wave -noupdate /tb/u_apb_ms_model/clk
add wave -noupdate /tb/u_apb_ms_model/rstn
add wave -noupdate /tb/u_apb_ms_model/psel
add wave -noupdate /tb/u_apb_ms_model/penable
add wave -noupdate /tb/u_apb_ms_model/paddr
add wave -noupdate /tb/u_apb_ms_model/pwrite
add wave -noupdate /tb/u_apb_ms_model/pwdata
add wave -noupdate /tb/u_apb_ms_model/pready
add wave -noupdate /tb/u_apb_ms_model/prdata
add wave -noupdate /tb/u_apb_ms_model/intr
add wave -noupdate -divider cdma_top
add wave -noupdate /tb/u_cdma/clk
add wave -noupdate /tb/u_cdma/rstn
add wave -noupdate /tb/u_cdma/arvalid
add wave -noupdate /tb/u_cdma/arready
add wave -noupdate /tb/u_cdma/arsize
add wave -noupdate /tb/u_cdma/arid
add wave -noupdate /tb/u_cdma/araddr
add wave -noupdate /tb/u_cdma/arlen
add wave -noupdate /tb/u_cdma/arsize
add wave -noupdate /tb/u_cdma/rvalid
add wave -noupdate /tb/u_cdma/rready
add wave -noupdate /tb/u_cdma/rlast
add wave -noupdate /tb/u_cdma/rid
add wave -noupdate /tb/u_cdma/rdata
add wave -noupdate /tb/u_cdma/awvalid
add wave -noupdate /tb/u_cdma/awready
add wave -noupdate /tb/u_cdma/awaddr
add wave -noupdate /tb/u_cdma/awlen
add wave -noupdate /tb/u_cdma/awsize
add wave -noupdate /tb/u_cdma/wvalid
add wave -noupdate /tb/u_cdma/wready
add wave -noupdate /tb/u_cdma/wlast
add wave -noupdate /tb/u_cdma/wstrb
add wave -noupdate /tb/u_cdma/wdata
add wave -noupdate -divider cfg
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_sar
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_dar
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_trans_xsize
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_trans_ysize
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_sa_ystep
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_da_ystep
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_llr
add wave -noupdate /tb/u_cdma/u_cdma_cfg/cfg_dma_halt
add wave -noupdate /tb/u_cdma/u_cdma_cfg/buf_err
add wave -noupdate /tb/u_cdma/u_cdma_cfg/ll_req
add wave -noupdate /tb/u_cdma/u_cdma_cfg/ll_addr
add wave -noupdate /tb/u_cdma/u_cdma_cfg/ll_ack
add wave -noupdate /tb/u_cdma/u_cdma_cfg/ll_dvld
add wave -noupdate /tb/u_cdma/u_cdma_cfg/ll_rdata
add wave -noupdate /tb/u_cdma/u_cdma_cfg/ll_dcnt
add wave -noupdate /tb/u_cdma/u_cdma_cfg/intr
add wave -noupdate -divider buffer
add wave -noupdate /tb/u_cdma/u_cdma_buf/clk
add wave -noupdate /tb/u_cdma/u_cdma_buf/buf_wr
add wave -noupdate /tb/u_cdma/u_cdma_buf/buf_wdata
add wave -noupdate /tb/u_cdma/u_cdma_buf/buf_rd
add wave -noupdate /tb/u_cdma/u_cdma_buf/buf_rdata
add wave -noupdate /tb/u_cdma/u_cdma_buf/buf_empty
add wave -noupdate /tb/u_cdma/u_cdma_buf/rptr
add wave -noupdate /tb/u_cdma/u_cdma_buf/wptr
add wave -noupdate /tb/u_cdma/u_cdma_buf/buf_empty_word
add wave -noupdate /tb/u_cdma/u_cdma_buf/buf_buf_word
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {54597099140 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 233
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 3
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {7541748050 ps}
