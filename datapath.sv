`timescale 1ns / 1ps
`include "defines.vh"

module datapath (
    // ctrl
    input  wire        clk,
    input  wire        rst,
    input  wire [5 :0] ext_int ,
    // inst
    input  wire        i_stall,
    output wire        stallF,
    output wire        inst_sram_en, 
    output wire [31:0] F_pc,
    output wire [31:0] F_pc_next,
    input  wire        inst_data_ok1,
    input  wire        inst_data_ok2,
    input  wire [31:0] inst_rdata1,
    input  wire [31:0] inst_rdata2,
    // data
    input  wire        d_stall,
    output wire        stallM,
    output wire        mem_read_enE,
    output wire        mem_write_enE,
    output wire [31:0] mem_addrE,
    input  wire [31:0] data_sram_rdataM,
    output wire        data_sram_enM,
    output wire [ 1:0] data_sram_rlenM,
    output wire [ 3:0] data_sram_wenM,
    output wire [31:0] data_sram_addrM,
    output wire [31:0] data_sram_wdataM,
    //debug
    output wire [31:0] debug_wb_pc,      
    output wire [3 :0] debug_wb_rf_wen,
    output wire [4 :0] debug_wb_rf_wnum, 
    output wire [31:0] debug_wb_rf_wdata
);

// ====================================== 变量定义区 ======================================
wire clear, ena;
assign clear = 1'b0;
assign ena = 1'b1;

// =====其他信号=====
// fifo
wire            fifo_empty;
wire            fifo_almost_empty;
wire            fifo_full;
// 流水线控制信号
wire            F_ena;
wire            D_ena;
wire            D_slave_ena;
wire            E_ena;
wire            M_ena;
wire            W_ena;
wire            F_flush;
wire            D_flush;
wire            E_flush;
wire            M_flush;
wire            W_flush;
wire            E_alu_stall;
// except
wire [31:0]     M_bad_addr;
wire            M_except;
wire [31:0]     M_excepttype;
wire [31:0]     M_except_inst_addr;
wire            M_except_in_delayslot;
wire [31:0]     M_pc_except_target;
// cp0
wire 			cp0_timer_int;
wire [31:0]     cp0_data;
wire [31:0]     cp0_count;
wire [31:0]     cp0_compare;
wire [31:0]     cp0_status;
wire [31:0]     cp0_cause;
wire [31:0]     cp0_epc;
wire [31:0]     cp0_config;
wire [31:0]     cp0_prid;
wire [31:0]     badvaddr;
// hilo
wire [63:0]     hilo;

// ===== F =====
wire            F_pc_except                 ;

// ===== D =====
wire [31:0]     D_master_inst     ,D_slave_inst    ;
wire [31:0]     D_master_pc       ,D_slave_pc      ;
wire            D_master_is_in_delayslot ,D_slave_is_in_delayslot ;
// inst
wire [5:0]      D_master_op              ,D_slave_op              ;
wire [4:0]      D_master_shamt           ,D_slave_shamt           ;
wire [5:0]      D_master_funct           ,D_slave_funct           ;
wire [15:0]     D_master_imm             ,D_slave_imm             ;
wire [31:0]     D_master_imm_value       ,D_slave_imm_value       ;
wire            D_master_is_hilo_accessed,D_slave_is_hilo_accessed;
wire            D_master_spec_inst       ,D_slave_spec_inst       ;
wire            D_master_break_inst      ,D_slave_break_inst      ;
wire            D_master_syscall_inst    ,D_slave_syscall_inst    ;
wire            D_master_eret_inst       ,D_slave_eret_inst       ;
wire            D_master_undefined_inst  ,D_slave_undefined_inst  ;
wire            D_master_memRead         ,D_slave_memRead         ;
wire            D_master_flush_all;
wire            D_slave_is_only_in_master;
wire            E_master_memWrite;
wire            E_master_memRead ;
// branch
wire [3:0]      D_master_branch_type     ,D_slave_branch_type     ;
wire            D_master_is_link_pc8     ,D_slave_is_link_pc8     ;
wire [25:0]     D_master_j_target        ,D_slave_j_target        ;
wire [3:0]      D_master_trap_type       ,D_slave_trap_type       ;
// alu
wire [7:0]      D_master_aluop           ,D_slave_aluop           ;
wire            D_master_alu_sela        ,D_slave_alu_sela        ;
wire            D_master_alu_selb        ,D_slave_alu_selb        ;
// reg
wire [4:0]      D_master_rs              ,D_slave_rs              ;
wire [4:0]      D_master_rt              ,D_slave_rt              ;
wire [4:0]      D_master_rd              ,D_slave_rd              ;
wire [31:0]     D_master_rs_value_tmp    ,D_slave_rs_value_tmp    ;
wire [31:0]     D_master_rt_value_tmp    ,D_slave_rt_value_tmp    ;
wire [31:0]     D_master_rs_value        ,D_slave_rs_value        ;
wire [31:0]     D_master_rt_value        ,D_slave_rt_value        ;
wire            D_master_reg_wen         ,D_slave_reg_wen         ;
wire [4:0]      D_master_reg_waddr       ,D_slave_reg_waddr       ;
// mem
wire            D_master_mem_en          ,D_slave_mem_en          ;
wire            D_master_memWrite        ,D_slave_memWrite        ;
wire            D_master_memtoReg        ,D_slave_memtoReg        ;
// other
wire            D_master_cp0write        ,D_slave_cp0write        ;
wire            D_master_hilowrite       ,D_slave_hilowrite       ;
wire            D_master_is_pc_except    ,D_slave_is_pc_except    ;
wire [`CmovBus] D_master_cmov_type       ,D_slave_cmov_type       ;

// ===== E =====
wire [4 :0]     E_master_rs,E_master_rt,E_slave_rs,E_slave_rt;
wire 	        E_master_exp_trap ,E_slave_exp_trap;
wire [3 :0]     E_master_trap_type,E_slave_trap_type;
wire            E_slave_ena;
wire [31:0]     E_master_inst     ,E_slave_inst    ;
wire            E_branch_taken;
wire [31:0]     E_pc_branch_target;
wire [ 3:0]     E_master_branch_type;
wire [ 4:0]     E_master_shamt          ;
wire [31:0]     E_master_rs_value       ;
wire [31:0]     E_master_rt_value       ;
wire [31:0]     E_master_imm_value      ;
wire [ 7:0]     E_master_aluop          ;
wire [25:0]     E_master_j_target       ;
wire [31:0]     E_master_pc             ;  
wire            E_master_is_link_pc8    ;
wire            E_master_mem_en         ;
wire            E_master_hilowrite      ;
wire [ 5:0]     E_master_op             ;  
wire            E_master_memtoReg       , E_slave_memtoReg;
wire            E_master_reg_wen_a      , E_slave_reg_wen_a;
wire            E_master_reg_wen        , E_slave_reg_wen  ;
wire [ 4:0]     E_master_reg_waddr      ;
wire [ 4:0]     E_slave_shamt           ;
wire [31:0]     E_slave_rs_value        ;
wire [31:0]     E_slave_rt_value        ;
wire [31:0]     E_slave_imm_value       ;
wire [ 7:0]     E_slave_aluop           ;
wire [31:0]     E_slave_pc              ;
wire [ 4:0]     E_slave_reg_waddr       ;
wire            E_slave_is_link_pc8     ;
wire			E_slave_hilowrite		;
wire            E_master_is_in_delayslot,E_slave_is_in_delayslot;
wire [`EXCEPT_BUS]E_master_except       ,E_slave_except         ;
wire [`CmovBus] E_master_cmov_type      ,E_slave_cmov_type      ;
wire            E_master_cp0write, E_slave_cp0write ;
wire [ 4:0]     E_master_rd             ;
// alu
wire            E_master_alu_sela,E_slave_alu_sela;
wire            E_master_alu_selb,E_slave_alu_selb;
wire [31:0]     E_master_alu_srca,E_slave_alu_srca;
wire [31:0]     E_master_alu_srcb,E_slave_alu_srcb;
wire [31:0]     E_master_alu_res_tmp;
wire [31:0]     E_master_alu_res ,E_slave_alu_res;
wire [31:0]     E_master_mem_addr ;
wire [63:0]     E_master_alu_out64;
wire            E_master_overflow,E_slave_overflow;

// ===== M =====
wire [7 :0]     M_master_aluop    ,M_slave_aluop   ;
wire [31:0]     M_master_inst     ,M_slave_inst    ;
wire            M_master_hilowrite;
wire            M_master_is_link_pc8;
wire            M_master_mem_en   ;
wire            M_master_memtoReg ,M_slave_memtoReg ;
wire            M_master_cp0write ,M_slave_cp0write ;
wire [ 5:0]     M_master_op       ;
wire [31:0]     M_master_pc       ,M_slave_pc       ;
wire [31:0]     M_master_rt_value ;
wire            M_master_reg_wen  ,M_slave_reg_wen  ;
wire [31:0]     M_master_alu_res  ,M_slave_alu_res  ;
wire [63:0]     M_master_alu_out64;
wire [31:0]     M_master_mem_rdata;
wire [31:0]     M_master_mem_addr ;
wire [ 4:0]     M_master_reg_waddr,M_slave_reg_waddr ;
wire [`EXCEPT_BUS]     M_master_except_a, M_slave_except_a;
wire [`EXCEPT_BUS]     M_master_except, M_slave_except;
wire            M_master_is_in_delayslot, M_slave_is_in_delayslot;
wire [ 4:0]     M_master_rd       ;


// ===== W =====
wire [31:0]     W_master_inst     ,W_slave_inst    ;
wire [31:0]     W_master_pc       ,W_slave_pc      ;
wire [31:0]     W_master_mem_rdata;
wire [31:0]     W_master_alu_res  ,W_slave_alu_res  ;
wire            W_master_reg_wen  ,W_slave_reg_wen  ;
wire [ 4:0]     W_master_reg_waddr,W_slave_reg_waddr;
wire [31:0]     W_master_reg_wdata,W_slave_reg_wdata;
wire [`EXCEPT_BUS]     W_master_except   , W_slave_except  ;
wire [63:0]     W_master_alu_out64;


// 异常数据从上至下传递
// _except = [8trap, 7pc_exp, 6syscall, 5break, 4eret, 3undefined, 2overflow, 1adel, 0ades]
assign M_except = (|M_excepttype);
assign D_master_is_pc_except  = (|D_master_pc[1:0]); // 2'b00
assign D_slave_is_pc_except   = (|D_slave_pc[1:0]);

// 冒险处理
hazard u_hazard(
    //ports
    .i_stall                        ( i_stall                        ),
    .d_stall                        ( d_stall                        ),
    .D_master_rs                    ( D_master_rs                    ),
    .D_master_rt                    ( D_master_rt                    ),
    .E_master_memtoReg              ( E_master_memtoReg              ),
    .E_master_reg_waddr             ( E_master_reg_waddr             ),
    .E_slave_memtoReg               ( E_slave_memtoReg               ),
    .E_slave_reg_waddr              ( E_slave_reg_waddr              ),
    .E_branch_taken                 ( E_branch_taken                 ),
    .E_alu_stall                    ( E_alu_stall                    ),
    .D_flush_all                    ( D_master_flush_all             ),
    .M_except                       ( M_except                       ),
    .F_ena                          ( F_ena                          ),
    .D_ena                          ( D_ena                          ),
    .E_ena                          ( E_ena                          ),
    .M_ena                          ( M_ena                          ),
    .W_ena                          ( W_ena                          ),
    .F_flush                        ( F_flush                        ),
    .D_flush                        ( D_flush                        ),
    .E_flush                        ( E_flush                        ),
    .M_flush                        ( M_flush                        ),
    .W_flush                        ( W_flush                        )
);

// ====================================== Fetch ======================================
assign F_pc_except = (|F_pc[1:0]); // 必须是2'b00
// FIXME: 注意，这里如果是i_stall导致的F_ena=0，inst_sram_en仍然使能(不太确定这个逻辑)
// assign inst_sram_en =  !(rst | M_except | F_pc_except | fifo_full);  // assign inst_sram_en =  !(rst | M_except | F_pc_except | fifo_full);  // fifo_full 不取指
assign inst_sram_en =  !(rst | M_except | fifo_full);
assign stallF = ~F_ena;
assign stallM = ~M_ena;
wire pc_en;
assign pc_en = F_ena | M_except; // 异常的优先级最高，必须使能

pc_reg u_pc_reg(
    //ports
    .clk                       ( clk                   ),
    .rst                       ( rst                   ),
    .pc_en                     ( pc_en                 ), 
    .inst_data_ok1             ( inst_data_ok1 ),
    .inst_data_ok2             ( inst_data_ok2 ),
    .flush_all                 ( D_master_flush_all    ),
    .flush_all_addr            ( D_master_pc + 4       ), 
    .fifo_full                 ( fifo_full             ), // fifo_full pc不变
    .is_except                 ( M_except              ),
    .except_addr               ( M_pc_except_target    ),       
    .branch_en                 ( E_ena                 ),
    .branch_taken              ( E_branch_taken        ),
    .branch_addr               ( E_pc_branch_target    ),
    
    .pc_next                   ( F_pc_next             ),
    .pc_curr                   ( F_pc                  )
);

inst_fifo u_inst_fifo(
    //ports
    .clk                          ( clk                    ),
    .rst                          ( rst                    ),
    .fifo_rst                     ( rst | D_flush | D_master_flush_all ),
    .D_ena                        ( D_ena                  ),
    .master_is_branch             ( (|D_master_branch_type)), // D阶段的branch
    .delay_rst                    (E_branch_taken && ~E_slave_ena), // next_master_is_in_delayslot
    
    .read_en1                     ( D_ena                  ),
    .read_en2                     ( D_slave_ena              ), // D阶段的发射结果
    .read_address1                ( D_master_pc            ),
    .read_address2                ( D_slave_pc             ),
    .read_data1                   ( D_master_inst          ),
    .read_data2                   ( D_slave_inst           ),
    
    .write_en1                    ( inst_data_ok1),
    .write_en2                    ( inst_data_ok2),
    .write_address1               ( F_pc                   ),
    .write_address2               ( F_pc + 32'd4           ),
    .write_data1                  ( inst_rdata1            ),
    .write_data2                  ( inst_rdata2            ),
    
    .master_is_in_delayslot_o     (D_master_is_in_delayslot),
    .empty                        ( fifo_empty             ),
    .almost_empty                 ( fifo_almost_empty      ),
    .full                         ( fifo_full              )
);


// ====================================== Decode ======================================
decoder u_decoder_master(
    //ports
    .instr                      ( D_master_inst                      ),
    .op                         ( D_master_op                         ),
    .rs                         ( D_master_rs                         ),
    .rt                         ( D_master_rt                         ),
    .rd                         ( D_master_rd                         ),
    .shamt                      ( D_master_shamt                      ),
    .funct                      ( D_master_funct                      ),
    .imm                        ( D_master_imm                        ),
    .sign_extend_imm_value      ( D_master_imm_value                  ),
    .j_target                   ( D_master_j_target                   ),
    .is_link_pc8                ( D_master_is_link_pc8                ),
    .branch_type                ( D_master_branch_type                ),
    .trap_type                  ( D_master_trap_type                  ),
    .cmov_type                  ( D_master_cmov_type                  ),
    .reg_waddr                  ( D_master_reg_waddr                  ),
    .aluop                      ( D_master_aluop                      ),
    .alu_sela                   ( D_master_alu_sela                   ),
    .alu_selb                   ( D_master_alu_selb                   ),
    .mem_en                     ( D_master_mem_en                     ),
    .memWrite                   ( D_master_memWrite                   ),
    .memRead                    ( D_master_memRead                    ),
    .memtoReg                   ( D_master_memtoReg                   ),
    .cp0write                   ( D_master_cp0write                   ),
    .hilowrite                  ( D_master_hilowrite                  ),
    .flush_all                  ( D_master_flush_all                  ),
    .reg_wen                    ( D_master_reg_wen                    ),
    .spec_inst                  ( D_master_spec_inst                  ),
    .undefined_inst             ( D_master_undefined_inst             ),
    .break_inst                 ( D_master_break_inst           ),
    .syscall_inst               ( D_master_syscall_inst         ),
    .eret_inst                  ( D_master_eret_inst            )
);

decoder u_decoder_slave(
    //ports
    .instr                      ( D_slave_inst                      ),
    .op                         ( D_slave_op                         ),
    .rs                         ( D_slave_rs                         ),
    .rt                         ( D_slave_rt                         ),
    .rd                         ( D_slave_rd                         ),
    .shamt                      ( D_slave_shamt                      ),
    .funct                      ( D_slave_funct                      ),
    .imm                        ( D_slave_imm                   ),
    .sign_extend_imm_value      ( D_slave_imm_value            ),
    .j_target                   ( D_slave_j_target                   ),
    .is_link_pc8                ( D_slave_is_link_pc8                ),
    .branch_type                ( D_slave_branch_type                ),
    .trap_type                  ( D_slave_trap_type                  ),
    .cmov_type                  ( D_slave_cmov_type                  ),
    .reg_waddr                  ( D_slave_reg_waddr                  ),
    .aluop                      ( D_slave_aluop                      ),
    .is_olny_in_master          ( D_slave_is_only_in_master          ),
    .alu_sela                   ( D_slave_alu_sela                   ),
    .alu_selb                   ( D_slave_alu_selb                   ),
    .mem_en                     ( D_slave_mem_en                     ),
    .memWrite                   ( D_slave_memWrite                   ),
    .memRead                    ( D_slave_memRead                    ),
    .memtoReg                   ( D_slave_memtoReg                   ),
    .cp0write                   ( D_slave_cp0write                   ),
    .hilowrite                  ( D_slave_hilowrite                  ),
    .reg_wen                    ( D_slave_reg_wen                    ),
    .spec_inst                  ( D_slave_spec_inst                  ),
    .undefined_inst             ( D_slave_undefined_inst             ),
    .break_inst                 ( D_slave_break_inst            ),
    .syscall_inst               ( D_slave_syscall_inst          ),
    .eret_inst                  ( D_slave_eret_inst             )
);


regfile u_regfile(
    //ports
    .clk               ( clk                    ),
    .rst               ( rst                    ),
    
    .ra1_a             ( D_master_rs            ),
    .rd1_a             ( D_master_rs_value_tmp  ),
    .ra1_b             ( D_master_rt            ),
    .rd1_b             ( D_master_rt_value_tmp  ),
    .wen1              ( W_master_reg_wen & W_ena & ~(|W_master_except)), // 跟踪异常，该指令出现异常，则不
    .wa1               ( W_master_reg_waddr     ),
    .wd1               ( W_master_reg_wdata     ),
    
    .ra2_a             ( D_slave_rs             ),
    .rd2_a             ( D_slave_rs_value_tmp   ),
    .ra2_b             ( D_slave_rt             ),
    .rd2_b             ( D_slave_rt_value_tmp   ),
    .wen2              ( W_slave_reg_wen & W_ena & ~(|W_slave_except) & ~(|W_master_except)),
    .wa2               ( W_slave_reg_waddr      ),
    .wd2               ( W_slave_reg_wdata      )
);

// 前推计算结果和访存结果 EM->D
forward_top u_forward_top(
	//ports
	.alu_wen1            		( E_slave_reg_wen & (!E_slave_memtoReg)),
	.alu_waddr1          		( E_slave_reg_waddr   		),
	.alu_wdata1          		( E_slave_alu_res   		),
	.alu_wen2            		( E_master_reg_wen & (!E_master_memtoReg)),
	.alu_waddr2          		( E_master_reg_waddr  		),
	.alu_wdata2          		( E_master_alu_res  		),
	.alu_wen3            		( M_slave_reg_wen           ), // 计算结果和访存结果
	.alu_waddr3          		( M_slave_reg_waddr   		),
	.alu_wdata3          		( M_slave_reg_wdata   		),
	.alu_wen4            		( M_master_reg_wen          ),
	.alu_waddr4          		( M_master_reg_waddr  		),
	.alu_wdata4          		( M_master_reg_wdata  		),
	// .memtoReg            		( M_master_memtoReg   		),
	// .mem_waddr           		( M_master_reg_waddr  		),
	// .mem_rdata           		( M_master_mem_rdata  		),
	.master_rs           		( D_master_rs         		),
	.master_rs_value_tmp 		( D_master_rs_value_tmp 	),
	.master_rs_value     		( D_master_rs_value   		),
	.master_rt           		( D_master_rt         		),
	.master_rt_value_tmp 		( D_master_rt_value_tmp 	),
	.master_rt_value     		( D_master_rt_value   		),
	.slave_rs            		( D_slave_rs          		),
	.slave_rs_value_tmp  		( D_slave_rs_value_tmp		),
	.slave_rs_value      		( D_slave_rs_value    		),
	.slave_rt            		( D_slave_rt          		),
	.slave_rt_value_tmp  		( D_slave_rt_value_tmp		),
	.slave_rt_value      		( D_slave_rt_value    		)
);

issue_ctrl u_issue_ctrl(
	//ports
	.D_master_en               		( D_ena                        		),
	.D_master_reg_wen          		( D_master_reg_wen          		),
	.D_master_mem_en           		( D_master_mem_en           		),
	.D_master_reg_waddr        		( D_master_reg_waddr        		),
	.D_master_is_branch        		( (|D_master_branch_type)     		),
	.D_master_is_spec_inst     		( D_master_spec_inst         		),
	.E_master_memtoReg         		( E_master_memtoReg         		),
	.E_master_reg_waddr        		( E_master_reg_waddr        		),
    .E_slave_memtoReg               ( E_slave_memtoReg                  ),
    .E_slave_reg_waddr              ( E_slave_reg_waddr                 ),
	.D_slave_op                		( D_slave_op                		),
	.D_slave_rs                		( D_slave_rs                		),
	.D_slave_rt                		( D_slave_rt                		),
	.D_slave_mem_en            		( D_slave_mem_en            		),
	.D_slave_is_branch         		( (|D_slave_branch_type)      		),
	.D_slave_is_spec_inst      		( D_slave_spec_inst           		),
	.D_slave_is_only_in_master 		( D_slave_is_only_in_master 		),
	.fifo_empty                		( fifo_empty                		),
	.fifo_almost_empty         		( fifo_almost_empty         		),
	.D_slave_is_in_delayslot   		( D_slave_is_in_delayslot   		),
	.D_slave_en                		( D_slave_ena               		)
);

// ====================================== Execute ======================================
wire D2E_clear1,D2E_clear2;
// wire [31:0] E_master_rs_value_tmp,E_master_rt_value_tmp,E_slave_rs_value_tmp,E_slave_rt_value_tmp;
// 在使能的情况下跳转清空才成立
assign D2E_clear1 = M_except | (!D_master_is_in_delayslot & E_flush & E_ena) | (!D_ena & E_ena);
assign D2E_clear2 = M_except | (E_flush & D_slave_ena) || (E_ena & !D_slave_ena);
id_ex u_id_ex(
	//ports
	.clk                      		( clk                      		),
	.rst                      		( rst                      		),
	.clear1                   		( D2E_clear1              		),
	.clear2                   		( D2E_clear2               		),
	.ena1                     		( E_ena                  		),
    .ena2                     		( D_slave_ena                   ),
	.D_master_memtoReg        		( D_master_memtoReg        		),
	.D_master_reg_wen         		( D_master_reg_wen         		),
	.D_master_alu_sela        		( D_master_alu_sela        		),
	.D_master_alu_selb        		( D_master_alu_selb        		),
	.D_master_is_link_pc8     		( D_master_is_link_pc8     		),
	.D_master_mem_en          		( D_master_mem_en          		),
	.D_master_memWrite        		( D_master_memWrite        		),
	.D_master_memRead         		( D_master_memRead         		),
	.D_master_hilowrite       		( D_master_hilowrite       		),
	.D_master_cp0write        		( D_master_cp0write        		),
	.D_master_is_in_delayslot 		( D_master_is_in_delayslot 		),
	.D_master_branch_type     		( D_master_branch_type     		),
	.D_master_shamt           		( D_master_shamt           		),
	.D_master_reg_waddr       		( D_master_reg_waddr       		),
	.D_master_rd              		( D_master_rd              		),
	.D_master_aluop           		( D_master_aluop           		),
	.D_master_op              		( D_master_op              		),
	.D_master_except          		( {1'b0, D_master_is_pc_except,D_master_syscall_inst,D_master_break_inst,D_master_eret_inst,D_master_undefined_inst,3'b0}          		),
	.D_master_j_target        		( D_master_j_target        		),
	.D_master_pc              		( D_master_pc              		),
	.D_master_inst            		( D_master_inst            		),
	.D_master_rs_value        		( D_master_rs_value        		),
	.D_master_rt_value        		( D_master_rt_value        		),
	.D_master_imm_value       		( D_master_imm_value       		),
    .D_master_trap_type             ( D_master_trap_type            ),
    .D_master_cmov_type             ( D_master_cmov_type            ),
    .D_master_rs                    ( D_master_rs                   ),
    .D_master_rt                    ( D_master_rt                   ),
	.D_slave_reg_wen          		( D_slave_reg_wen          		),
	.D_slave_alu_sela         		( D_slave_alu_sela         		),
	.D_slave_alu_selb         		( D_slave_alu_selb         		),
	.D_slave_is_link_pc8      		( D_slave_is_link_pc8      		),
	.D_slave_op              		( D_slave_op              		),
    .D_slave_mem_en          		( D_slave_mem_en          		),
	.D_slave_memWrite        		( D_slave_memWrite        		),
	.D_slave_memRead         		( D_slave_memRead         		),
    .D_slave_memtoReg         		( D_slave_memtoReg         		),
	.D_slave_hilowrite				( D_slave_hilowrite				),
	.D_slave_cp0write         		( D_slave_cp0write         		),
	.D_slave_is_in_delayslot  		( D_slave_is_in_delayslot  		),
	.D_slave_shamt            		( D_slave_shamt            		),
	.D_slave_reg_waddr        		( D_slave_reg_waddr        		),
	.D_slave_aluop            		( D_slave_aluop            		),
	.D_slave_except           		( {1'b0, D_slave_is_pc_except,D_slave_syscall_inst,D_slave_break_inst,D_slave_eret_inst,D_slave_undefined_inst,3'b0}           		),
	.D_slave_inst             		( D_slave_inst             		),
	.D_slave_rs_value         		( D_slave_rs_value         		),
	.D_slave_rt_value         		( D_slave_rt_value         		),
	.D_slave_imm_value        		( D_slave_imm_value        		),
	.D_slave_pc               		( D_slave_pc               		),
    .D_slave_trap_type              ( D_slave_trap_type             ),
    .D_slave_cmov_type              ( D_slave_cmov_type             ),
    .D_slave_rs                     ( D_slave_rs                    ),
    .D_slave_rt                     ( D_slave_rt                    ),
	.E_master_memtoReg        		( E_master_memtoReg        		),
	.E_master_reg_wen         		( E_master_reg_wen_a       		),
	.E_master_alu_sela        		( E_master_alu_sela        		),
	.E_master_alu_selb        		( E_master_alu_selb        		),
	.E_master_is_link_pc8     		( E_master_is_link_pc8     		),
	.E_master_mem_en          		( E_master_mem_en          		),
	.E_master_memWrite        		( E_master_memWrite        		),
	.E_master_memRead         		( E_master_memRead         		),
	.E_master_hilowrite       		( E_master_hilowrite       		),
	.E_master_cp0write        		( E_master_cp0write        		),
	.E_master_is_in_delayslot 		( E_master_is_in_delayslot 		),
	.E_master_branch_type     		( E_master_branch_type     		),
	.E_master_shamt           		( E_master_shamt           		),
	.E_master_reg_waddr       		( E_master_reg_waddr       		),
	.E_master_rd              		( E_master_rd              		),
	.E_master_aluop           		( E_master_aluop           		),
	.E_master_op              		( E_master_op              		),
	.E_master_except          		( E_master_except          		),
	.E_master_j_target        		( E_master_j_target        		),
	.E_master_pc              		( E_master_pc              		),
	.E_master_inst            		( E_master_inst            		),
	.E_master_rs_value        		( E_master_rs_value      		),
	.E_master_rt_value        		( E_master_rt_value      		),
	.E_master_imm_value       		( E_master_imm_value       		),
    .E_master_trap_type             ( E_master_trap_type            ),
    .E_master_cmov_type             ( E_master_cmov_type            ),
    .E_master_rs                    ( E_master_rs                   ),
    .E_master_rt                    ( E_master_rt                   ),
	.E_slave_ena                    ( E_slave_ena            		),
    .E_slave_reg_wen          		( E_slave_reg_wen_a        		),
	.E_slave_alu_sela         		( E_slave_alu_sela         		),
	.E_slave_alu_selb         		( E_slave_alu_selb         		),
	.E_slave_is_link_pc8      		( E_slave_is_link_pc8      		),
	.E_slave_op              		( E_slave_op              		),
    .E_slave_mem_en          		( E_slave_mem_en          		),
	.E_slave_memWrite        		( E_slave_memWrite        		),
	.E_slave_memRead         		( E_slave_memRead         		),
    .E_slave_memtoReg         		( E_slave_memtoReg         		),
	.E_slave_hilowrite				( E_slave_hilowrite				),
	.E_slave_cp0write         		( E_slave_cp0write         		),
	.E_slave_is_in_delayslot  		( E_slave_is_in_delayslot  		),
	.E_slave_shamt            		( E_slave_shamt            		),
	.E_slave_reg_waddr        		( E_slave_reg_waddr        		),
	.E_slave_aluop            		( E_slave_aluop            		),
	.E_slave_except           		( E_slave_except           		),
	.E_slave_inst             		( E_slave_inst             		),
	.E_slave_rs_value         		( E_slave_rs_value       		),
	.E_slave_rt_value         		( E_slave_rt_value       		),
    .E_slave_rs                     ( E_slave_rs                    ),
    .E_slave_rt                     ( E_slave_rt                    ),
	.E_slave_imm_value        		( E_slave_imm_value        		),
	.E_slave_pc               		( E_slave_pc               		),
    .E_slave_trap_type              ( E_slave_trap_type             ),
    .E_slave_cmov_type              ( E_slave_cmov_type             )
);

// 前推计算结果和访存结果 MW->E
// forwardE_top u_forwardE_top(
// 	//ports
// 	.M_slave_alu_wen     		( M_slave_reg_wen & (!M_slave_memtoReg)),
// 	.M_slave_alu_waddr   		( M_slave_reg_waddr   		),
// 	.M_slave_alu_wdata   		( M_slave_alu_res   		),
// 	.M_master_alu_wen    		( M_master_reg_wen & (!M_master_memtoReg)),
// 	.M_master_alu_waddr  		( M_master_reg_waddr  		),
// 	.M_master_alu_wdata  		( M_master_alu_res  		),
// 	.W_slave_alu_wen     		( W_slave_reg_wen & (!W_slave_memtoReg)),
// 	.W_slave_alu_waddr   		( W_slave_reg_waddr   		),
// 	.W_slave_alu_wdata   		( W_slave_alu_res   		),
// 	.W_master_alu_wen    		( W_master_reg_wen & (!W_master_memtoReg)),
// 	.W_master_alu_waddr  		( W_master_reg_waddr  		),
// 	.W_master_alu_wdata  		( W_master_alu_res  		),
// 	.W_master_memtoReg   		( W_master_memtoReg   		),
// 	.W_master_mem_waddr  		( W_master_reg_waddr  		),
// 	.W_master_mem_rdata  		( W_master_mem_rdata  		),
// 	.E_master_rs         		( E_master_rs         		),
// 	.E_master_rs_value_a 		( E_master_rs_value_a 		),
// 	.E_master_rs_value   		( E_master_rs_value   		),
// 	.E_master_rt         		( E_master_rt         		),
// 	.E_master_rt_value_a 		( E_master_rt_value_a 		),
// 	.E_master_rt_value   		( E_master_rt_value   		),
// 	.E_slave_rs          		( E_slave_rs          		),
// 	.E_slave_rs_value_a  		( E_slave_rs_value_a  		),
// 	.E_slave_rs_value    		( E_slave_rs_value    		),
// 	.E_slave_rt          		( E_slave_rt          		),
// 	.E_slave_rt_value_a  		( E_slave_rt_value_a  		),
// 	.E_slave_rt_value    		( E_slave_rt_value    		)
// );

// select_alusrc: 所有的pc要加8的，都在alu执行，进行电路复用
assign E_master_alu_srca =  E_master_alu_sela ? {{27{1'b0}},E_master_shamt} : E_master_rs_value;
assign E_master_alu_srcb =  E_master_alu_selb ? E_master_imm_value : E_master_rt_value;
assign E_slave_alu_srca  =  E_slave_alu_sela  ? {{27{1'b0}},E_slave_shamt} : E_slave_rs_value ;                            
assign E_slave_alu_srcb  =  E_slave_alu_selb  ? E_slave_imm_value : E_slave_rt_value ;

// reg_wen
assign E_master_reg_wen =   E_master_cmov_type==`C_MOVN ? (|E_master_rt_value):    // !=0
                            E_master_cmov_type==`C_MOVZ ? (!(|E_master_rt_value)): // ==0
                            E_master_reg_wen_a;
assign E_slave_reg_wen  =   E_slave_cmov_type==`C_MOVN ? (|E_slave_rt_value):    // !=0
                            E_slave_cmov_type==`C_MOVZ ? (!(|E_slave_rt_value)): // ==0
                            E_slave_reg_wen_a;

branch_judge u_branch_judge(
    //ports
    .branch_type                   ( E_master_branch_type                   ),
    .offset                        ( {E_master_imm_value[29:0],2'b00}  ),
    .j_target                      ( E_master_j_target                      ),
    .rs_value                      ( E_master_rs_value                       ),
    .rt_value                      ( E_master_rt_value                       ),
    .pc_plus4                      ( E_master_pc + 32'd4                      ),
    .branch_taken                  ( E_branch_taken                  ),
    .pc_branch_address             ( E_pc_branch_target             )
);

trap_judge u_trap_judge_master(
	//ports
	.trap_type 		( E_master_trap_type 		),
	.rs_value  		( E_master_rs_value   		),
	.rt_value  		( E_master_rt_value   		),
	.exp_trap  		( E_master_exp_trap  		)
);

trap_judge u_trap_judge_slave(
	//ports
	.trap_type 		( E_slave_trap_type 		),
	.rs_value  		( E_slave_rs_value   		),
	.rt_value  		( E_slave_rt_value   		),
	.exp_trap  		( E_slave_exp_trap  		)
);

wire E_master_alu_stall, E_slave_alu_stall;
wire [63:0] E_slave_alu_out64;
alu_master u_aluA(
    //ports
    .clk                   ( clk                    ),
    .rst                   ( rst | M_except         ),
    .aluop                 ( E_master_aluop         ),
    .a                     ( E_master_alu_srca      ),
    .b                     ( E_master_alu_srcb      ),
    .cp0_data              ( cp0_data               ),
    .hilo                  ( hilo                   ),
    .stall_alu             ( E_master_alu_stall     ),
    .y                     ( E_master_alu_res_tmp   ),
    .aluout_64             ( E_master_alu_out64     ),
    .overflow              ( E_master_overflow      )
);

alu_master u_aluB(
    //ports
    .clk                   ( clk                    ),
    .rst                   ( rst | M_except         ),
    .aluop                 ( E_slave_aluop          ),
    .a                     ( E_slave_alu_srca       ),
    .b                     ( E_slave_alu_srcb       ),
    .cp0_data              ( cp0_data               ),
    .hilo                  ( hilo                   ),
    .stall_alu             ( E_slave_alu_stall      ),
    .y                     ( E_slave_alu_res        ),
    .aluout_64             ( E_slave_alu_out64      ),
    .overflow              ( E_slave_overflow       )
);

assign E_alu_stall = E_master_alu_stall | E_slave_alu_stall;
assign E_master_alu_res = {32{E_master_is_link_pc8==1'b1}} & (E_master_pc + 32'd8) |
                          {32{E_master_is_link_pc8==1'b0}} & E_master_alu_res_tmp  ;

wire hilo_wen;
wire [63:0]hilo_wdata;
// TODO: 很多写，都有这种操作，regfile, except, hilo_reg，可以聚集一起吗？
assign hilo_wen = ((E_slave_hilowrite & ~(|E_master_except) & ~(|E_slave_except)) | (E_master_hilowrite & ~(|E_master_except))) & M_ena & ~M_flush;
assign hilo_wdata = E_slave_hilowrite ? E_slave_alu_out64 : E_master_alu_out64;
// assign hilo_wdata = {64{E_slave_hilowrite}}  & E_slave_alu_out64 | 
// 					{64{E_master_hilowrite}} & E_master_alu_out64;
// E阶段写，M阶段出结果
hilo_reg u_hilo_reg(
    //ports
    .clk                ( clk                ),
    .rst                ( rst                ),
    .wen                ( hilo_wen           ), // 保证E_master_hilowrite能成功送到M
    .hilo_i             ( hilo_wdata         ),  
    .hilo_o             ( hilo               )
);

/*alu_res_select u_alu_res_select_master(
	//ports
	.aluop       		( E_master_aluop       		),
	.is_link_pc8        ( E_master_is_link_pc8      ),
    .cp0_data    		( cp0_data    		        ),
	.pc8                ( E_master_pc + 32'd8       ),
    .alu_res_tmp 		( E_master_alu_res_tmp 		),
	.hilo        		( hilo        		        ),
	.alu_res     		( E_master_alu_res     		)
);

// E阶段写，M阶段出结果
hilo_reg u_hilo_reg(
	//ports
	.clk      		( clk      		    ),
	.rst      		( rst      		    ),
	.wen            ( E_master_hilowrite & M_ena & ~M_flush), // 保证E_master_hilowrite能成功送到M
	.aluop    		( E_master_aluop    ),
	.rs_value 		( E_master_rs_value ),
	.hilo_i   		( E_master_alu_out64),
	.hilo_o   		( hilo   		    )
);*/

// mem_addr && 提前访存
wire [31:0] E_slave_mem_addr ;
wire [5 :0] E_slave_op ;
wire        E_slave_mem_en ;
wire        E_slave_memWrite ;
wire        E_slave_memRead ;
wire        M_slave_mem_en ;
wire [31:0] M_slave_mem_rdata ;
wire [5 :0] mem_opE;
wire        mem_enE;
wire [31:0] mem_wdataE;
wire [31:0] mem_rdataM;
wire 		mem_enM;
wire 		mem_renM;
wire 		mem_wenM;
wire [5 :0] mem_opM;
wire [31:0] mem_addrM;
wire [31:0] mem_wdataM;
wire        E_master_mem_sel, E_slave_mem_sel ;
wire        M_master_mem_sel, M_slave_mem_sel ;

// mem_addr: base(rs value) + offset(immediate value)
assign E_master_mem_addr = E_master_rs_value + E_master_imm_value;
assign E_slave_mem_addr = E_slave_rs_value + E_slave_imm_value; 

struct_conflict u_struct_conflict(
	// datapath ctrl
	.E_exp1       		( |E_master_except  ),
	.E_exp2       		( |E_slave_except   ),
	.M_flush      		( M_flush           ),
	.M_ena        		( M_ena             ),
    // master
	.E_mem_en1    		( E_master_mem_en	),
	.E_mem_ren1   		( E_master_memRead  ),
	.E_mem_wen1   		( E_master_memWrite ),
	.E_mem_op1    		( E_master_op 		),
	.E_mem_addr1  		( E_master_mem_addr	),
	.E_mem_wdata1 		( E_master_rt_value ),
	.M_mem_sel1   		( M_master_mem_sel  ),
	.E_mem_sel1   		( E_master_mem_sel  ),
	.M_mem_rdata1 		( M_master_mem_rdata),
	// slave
    .E_mem_en2    		( E_slave_mem_en 	),
	.E_mem_ren2   		( E_slave_memRead   ),
	.E_mem_wen2   		( E_slave_memWrite  ),
	.E_mem_op2    		( E_slave_op  		),
	.E_mem_addr2  		( E_slave_mem_addr 	),
	.E_mem_wdata2 		( E_slave_rt_value  ),
	.M_mem_sel2   		( M_slave_mem_sel   ),
	.E_mem_sel2   		( E_slave_mem_sel   ),
	.M_mem_rdata2 		( M_slave_mem_rdata ),
	// mem
    .E_mem_en     		( mem_enE     		),
	.E_mem_ren    		( mem_read_enE		),
	.E_mem_wen    		( mem_write_enE     ),
	.E_mem_op     		( mem_opE     		),
	.E_mem_addr   		( mem_addrE 		),
	.E_mem_wdata  		( mem_wdataE  		),
	.M_mem_rdata  		( mem_rdataM 		)
);


// ====================================== Memory ======================================
// wire [31:0] M_master_alu_res_tmp, M_slave_alu_res_tmp;
ex_mem u_ex_mem(
	//ports
	.clk                      		( clk                      		),
	.rst                      		( rst                      		),
	.clear1                   		( M_flush                   	),
	.clear2                   		( M_flush                   	),
	.ena1                     		( M_ena                     	),
	.ena2                     		( M_ena                     	),
	.E_mem_en                       ( mem_enE                       ),
    .E_mem_ren                      ( mem_read_enE                  ),
    .E_mem_wen                      ( mem_write_enE                 ),
    .E_mem_op                       ( mem_opE                       ),
    .E_mem_addr                     ( mem_addrE                     ),
    .E_mem_wdata                    ( mem_wdataE                    ),
    .M_mem_en                       ( mem_enM                       ),
    .M_mem_ren                      ( mem_renM                      ),
    .M_mem_wen                      ( mem_wenM                      ),
    .M_mem_op                       ( mem_opM                       ),
    .M_mem_addr                     ( mem_addrM                     ),
    .M_mem_wdata                    ( mem_wdataM                    ),
    .E_master_mem_sel          		( E_master_mem_sel          	),
	.E_master_hilowrite       		( E_master_hilowrite       		),
	.E_master_memtoReg        		( E_master_memtoReg        		),
	.E_master_reg_wen         		( E_master_reg_wen         		),
	.E_master_cp0write        		( E_master_cp0write        		),
	.E_master_is_in_delayslot 		( E_master_is_in_delayslot 		),
	.E_master_reg_waddr       		( E_master_reg_waddr       		),
    .E_master_aluop                 ( E_master_aluop                ),
	.E_master_rd              		( E_master_rd              		),
	.E_master_op              		( E_master_op              		),
	.E_master_except_a        		( {E_master_exp_trap, E_master_except[7:3],E_master_overflow,E_master_except[1:0]}        		),
	.E_master_inst            		( E_master_inst            		),
	.E_master_rt_value        		( E_master_rt_value        		),
	.E_master_alu_res         		( E_master_alu_res         		),
	.E_master_pc              		( E_master_pc              		),
	.E_master_alu_out64       		( E_master_alu_out64       		),
    .E_master_mem_addr              ( E_master_mem_addr             ),
	.E_slave_reg_wen          		( E_slave_reg_wen          		),
	.E_slave_memtoReg         		( E_slave_memtoReg         		),
    .E_slave_mem_sel                ( E_slave_mem_sel               ),
	.E_slave_cp0write         		( E_slave_cp0write         		),
	.E_slave_is_in_delayslot  		( E_slave_is_in_delayslot  		),
	.E_slave_reg_waddr        		( E_slave_reg_waddr        		),
    .E_slave_aluop                  ( E_slave_aluop                 ),
	.E_slave_except           		( {E_slave_exp_trap, E_slave_except[7:3],E_slave_overflow,E_slave_except[1:0]}           		),
	.E_slave_pc               		( E_slave_pc               		),
	.E_slave_inst             		( E_slave_inst             		),
	.E_slave_alu_res          		( E_slave_alu_res          		),
	.M_master_mem_sel         		( M_master_mem_sel         		),
	.M_master_hilowrite       		( M_master_hilowrite       		),
	.M_master_memtoReg        		( M_master_memtoReg        		),
	.M_master_reg_wen         		( M_master_reg_wen         		),
	.M_master_cp0write        		( M_master_cp0write        		),
	.M_master_is_in_delayslot 		( M_master_is_in_delayslot 		),
	.M_master_reg_waddr       		( M_master_reg_waddr       		),
    .M_master_aluop                 ( M_master_aluop                ),
	.M_master_rd              		( M_master_rd              		),
	.M_master_op              		( M_master_op              		),
	.M_master_except_a        		( M_master_except_a        		),
	.M_master_inst            		( M_master_inst            		),
	.M_master_rt_value        		( M_master_rt_value        		),
	.M_master_alu_res         		( M_master_alu_res    		    ),
	.M_master_pc              		( M_master_pc              		),
	.M_master_alu_out64       		( M_master_alu_out64       		),
    .M_master_mem_addr              ( M_master_mem_addr             ),
	.M_slave_reg_wen          		( M_slave_reg_wen          		),
	.M_slave_mem_sel                ( M_slave_mem_sel               ),
    .M_slave_memtoReg         		( M_slave_memtoReg         		),
	.M_slave_cp0write         		( M_slave_cp0write         		),
	.M_slave_is_in_delayslot  		( M_slave_is_in_delayslot  		),
	.M_slave_reg_waddr        		( M_slave_reg_waddr        		),
    .M_slave_aluop                  ( M_slave_aluop                 ),
	.M_slave_except           		( M_slave_except_a         		),
	.M_slave_pc               		( M_slave_pc               		),
	.M_slave_inst             		( M_slave_inst             		),
	.M_slave_alu_res          		( M_slave_alu_res      		    )
);

mem_access u_mem_access(
	//ports
	.mem_en            		( mem_enM            		),
	.mem_op            		( mem_opM            		),
	.mem_wdata         		( mem_wdataM         		),
	.mem_addr          		( mem_addrM          		),
	.mem_rdata         		( mem_rdataM         		),
	.data_sram_rdata   		( data_sram_rdataM   		),
	.data_sram_en      		( data_sram_enM      		),
	.data_sram_rlen    		( data_sram_rlenM    		),
	.data_sram_wen     		( data_sram_wenM     		),
	.data_sram_addr    		( data_sram_addrM    		),
	.data_sram_wdata   		( data_sram_wdataM   		),
	// 异常处理及其选择
    .M_master_mem_sel  		( M_master_mem_sel  		),
	.M_slave_mem_sel   		( M_slave_mem_sel   		),
	.M_master_except_a 		( M_master_except_a 		),
	.M_master_except   		( M_master_except   		),
	.M_slave_except_a  		( M_slave_except_a  		),
	.M_slave_except    		( M_slave_except    		)
);

// master的异常优先级更高，故异常处理阶段先选择master异常
exception u_exp(
    //ports
    .rst            ( rst            ),
    .master_except  ( M_master_except),
    .master_pc      ( M_master_pc    ),
    .mem_addr       ( mem_addrM      ), // 虚地址
    .slave_except   ( M_slave_except ),
    .slave_pc       ( M_slave_pc     ),
    .cp0_status     ( cp0_status      ),
    .cp0_cause      ( cp0_cause       ),
    .cp0_epc        ( cp0_epc         ),
    .master_is_in_delayslot( M_master_is_in_delayslot),
    .slave_is_in_delayslot ( M_slave_is_in_delayslot ),
    
    .except_inst_addr   ( M_except_inst_addr),
    .except_in_delayslot( M_except_in_delayslot),
    .except_target      ( M_pc_except_target),
    .except_bad_addr    ( M_bad_addr        ),
    .excepttype         ( M_excepttype   )
);

// FIXME: CP0改成E写，M出结果，1.减少前推；2.减少因为例外导致的刷新数
cp0_reg u_cp0_reg(
    //ports
    .clk                    ( clk                        ),
    .rst                    ( rst                        ),
    .we_i                   ( M_master_cp0write  & M_ena ),  // 只有master访问cp0_reg
    .waddr_i                ( M_master_rd                ),  // M阶段写入CP0  // MTCP0 CP0[rd, sel] ← GPR[rt] 
    .raddr_i                ( E_master_rd                ),  // E阶段读取CP0，这两步可以避免数据冒险处理 // MFCP0 GPR[rt] ← CP0[rd, sel] 写寄存器
    .data_i                 ( M_master_rt_value          ),
    .int_i                  ( ext_int                    ),
    .excepttype_i           ( M_excepttype               ),
    .current_inst_addr_i    ( M_except_inst_addr         ),
    .is_in_delayslot_i      ( M_except_in_delayslot      ),
    .bad_addr_i             ( M_bad_addr                 ),
    .data_o                 ( cp0_data                   ),
    .count_o                ( cp0_count                  ),
    .compare_o              ( cp0_compare                ),
    .status_o               ( cp0_status                 ),
    .cause_o                ( cp0_cause                  ),
    .epc_o                  ( cp0_epc                    ),
    .config_o               ( cp0_config                 ),
    .prid_o                 ( cp0_prid                   ),
    .badvaddr_o             ( badvaddr                   ),
    .timer_int_o            ( cp0_timer_int              )
);

wire [31:0] M_master_reg_wdata, M_slave_reg_wdata;
assign M_master_reg_wdata = M_master_memtoReg ? M_master_mem_rdata : M_master_alu_res;
assign M_slave_reg_wdata = M_slave_memtoReg ? M_slave_mem_rdata : M_slave_alu_res;
// ====================================== WriteBack ======================================
mem_wb u_mem_wb(
	//ports
	.clk                		( clk                		),
	.rst                		( rst                		),
	.clear1             		( W_flush             		),
	.clear2             		( W_flush             		),
	.ena1                		( W_ena               		),
	.ena2               		( W_ena               		),
	.M_master_reg_wen   		( M_master_reg_wen   		),
	.M_master_reg_waddr 		( M_master_reg_waddr 		),
	.M_master_except    		( M_master_except    		),
	.M_master_inst      		( M_master_inst      		),
	.M_master_pc        		( M_master_pc        		),
	.M_master_reg_wdata 		( M_master_reg_wdata 		),
	.M_slave_reg_wen    		( M_slave_reg_wen    		),
	.M_slave_reg_waddr  		( M_slave_reg_waddr  		),
	.M_slave_except     		( M_slave_except     		),
	.M_slave_inst       		( M_slave_inst       		),
	.M_slave_pc         		( M_slave_pc         		),
	.M_slave_reg_wdata  		( M_slave_reg_wdata  		),
	.W_master_reg_wen   		( W_master_reg_wen   		),
	.W_master_reg_waddr 		( W_master_reg_waddr 		),
	.W_master_except    		( W_master_except    		),
	.W_master_inst      		( W_master_inst      		),
	.W_master_pc        		( W_master_pc        		),
	.W_master_reg_wdata 		( W_master_reg_wdata 		),
	.W_slave_reg_wen    		( W_slave_reg_wen    		),
	.W_slave_reg_waddr  		( W_slave_reg_waddr  		),
	.W_slave_except     		( W_slave_except     		),
	.W_slave_inst       		( W_slave_inst       		),
	.W_slave_pc         		( W_slave_pc         		),
	.W_slave_reg_wdata  		( W_slave_reg_wdata  		)
);

// debug
assign debug_wb_pc          =  W_ena ?((clk) ? W_master_pc : W_slave_pc) : 32'd0;
assign debug_wb_rf_wen      = (rst) ? 4'b0000 : ((clk) ? {4{u_regfile.wen1}} : {4{u_regfile.wen2}});
assign debug_wb_rf_wnum     = (clk) ? u_regfile.wa1 : u_regfile.wa2;
assign debug_wb_rf_wdata    = (clk) ? u_regfile.wd1 : u_regfile.wd2;
// ascii
wire [47:0] master_asciiF;
wire [47:0] master_asciiD;
wire [47:0] master_asciiE;
wire [47:0] master_asciiM;
wire [47:0] master_asciiW;
wire [47:0] slave_asciiF ;
wire [47:0] slave_asciiD ;
wire [47:0] slave_asciiE ;
wire [47:0] slave_asciiM ;
wire [47:0] slave_asciiW ;
instdec u_master_asciiF(inst_rdata1,master_asciiF);
instdec u_master_asciiD(D_master_inst,master_asciiD);
instdec u_master_asciiE(E_master_inst,master_asciiE);
instdec u_master_asciiM(M_master_inst,master_asciiM);
instdec u_master_asciiW(W_master_inst,master_asciiW);
instdec u_slave_asciiF (inst_rdata2,slave_asciiF );
instdec u_slave_asciiD (D_slave_inst ,slave_asciiD );
instdec u_slave_asciiE (E_slave_inst ,slave_asciiE );
instdec u_slave_asciiM (M_slave_inst ,slave_asciiM );
instdec u_slave_asciiW (W_slave_inst ,slave_asciiW );


endmodule