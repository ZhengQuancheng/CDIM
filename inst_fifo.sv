`timescale 1ns / 1ps

module inst_fifo(
        input                       clk,
        input                       rst,
        input                       fifo_rst, // rst || flush || ex_branch_taken   
        // 如果是branch，就不会再顺序取指，需要清空，清空的方式不是数据全部清零，而是指针归零就是了！在fifo中，指针才是王者！
        input                       master_is_branch,

        // Read inputs
        input                       read_en1,
        input                       read_en2,
        // output logic                delay_slot_out1,  // 延迟槽指令识别？
        output logic [31:0]         read_data1,  // fifo读出数据 if_id_instruction
        output logic [31:0]         read_data2,  // if_id_instruction_slave
        output logic [31:0]         read_addres1, // if_id_pc_address
        output logic [31:0]         read_addres2, // if_id_pc_address_slave
        output logic [11:0]         inst_exp1,  // 异常 if_id_inst_exp
        output logic [11:0]         inst_exp2,  // 异常 if_id_inst_exp_slave

        // Write inputs
        input                       write_en1, // 数据读回 ==> inst_ok & inst_ok_1
        input                       write_en2, // 数据读回 ==> inst_ok & inst_ok_2
        input [11:0]                write_inst_exp1,  // XXX  异常传递, 12bit？没懂{mem_exl_set_mem,mem_cp0_curr_ASID,if_inst_miss,if_inst_illegal,if_inst_tlb_invalid}
        input [31:0]                write_address1, // if_pc_address
        input [31:0]                write_address2,  // if_pc_address + 32'd4
        input [31:0]                write_data1, // 读回的数据写入 
        input [31:0]                write_data2, // 读回的数据写入
        
        output logic                master_is_in_delayslot_o,
        // fifo 状态
        output logic                empty, 
        output logic                almost_empty,  
        output logic                full
);

    // Reset status
    // reg         in_delay_slot;
    // reg         in_delay_slot_without_rst;
    // reg [11:0]  delayed_inst_exp;
    // reg [31:0]  delayed_data;
    // reg [31:0]  delayed_pc;
    // Store data here  16个data
    reg [31:0]  data[0:15];
    reg [31:0]  address[0:15];
    reg [11:0]  inst_exp[0:15];

    // Internal variables
    reg [3:0] write_pointer;
    reg [3:0] read_pointer;
    reg [3:0] data_count;

    // Status monitor
    assign full     = &data_count[3:1]; // 1110(装不下两条指令了) 
    assign empty    = (data_count == 4'd0); //0000
    assign almost_empty = (data_count == 4'd1); //0001

    // Output data
    wire [31:0] _read_data1 = data[read_pointer];
    wire [31:0] _read_data2 = data[read_pointer + 4'd1];
    wire [31:0] _read_addres1 = address[read_pointer];
    wire [31:0] _read_addres2 = address[read_pointer + 4'd1];
    wire [11:0] _inst_exp1 = inst_exp[read_pointer];
    wire [11:0] _inst_exp2 = inst_exp[read_pointer + 4'd1];

    // TODO 简易版处理延迟槽问题，但是没有考虑数据满的情况
    always_ff @(posedge clk)begin
        if(rst) master_is_in_delayslot_o = 1'b0;
        else if(master_is_branch) begin 
            if(!read_en2) 
                master_is_in_delayslot_o = 1'b1;
            else 
                master_is_in_delayslot_o = 1'b0;
        end
        else    master_is_in_delayslot_o = 1'b0;
    end
    // Delay slot data FSM
    // reg delay_slot_refill; // 是否要等待一周期

    // always_ff @(posedge clk) begin
    //     // 延迟
    //     if(fifo_rst && rst_with_delay && !write_en1 && 
    //         (read_pointer + 4'd1 == write_pointer || read_pointer == write_pointer)) begin
    //         delay_slot_refill   <= 1'd1;
    //     end
    //     // 上一次是延迟，但是写入了一个数据
    //     else if(delay_slot_refill && write_en1)
    //         delay_slot_refill   <= 1'd0;
    //     // 上一次是延迟，但是没有写入数据
    //     else if(delay_slot_refill)
    //         delay_slot_refill   <= delay_slot_refill;
    //     // 不延迟
    //     else
    //         delay_slot_refill   <= 1'd0;
    // end

    always_comb begin : select_output
        // if(in_delay_slot) begin
        //     read_data1       = delayed_data;
        //     read_data2       = 32'd0;
        //     read_addres1    = delayed_pc;
        //     read_addres2    = 32'd0;
        //     inst_exp1       = delayed_inst_exp;
        //     inst_exp2       = 12'd0;
        //     delay_slot_out1 = 1'd1;
        // end
        if(empty) begin
            read_data1       = 32'd0;
            read_data2       = 32'd0;
            read_addres1    = 32'd0;
            read_addres2    = 32'd0;
            inst_exp1       = 12'd0;
            inst_exp2       = 12'd0;
            // delay_slot_out1 = 1'd0;
        end
        else if(almost_empty) begin
            // 只能取一条数据
            read_data1       = _read_data1;
            read_data2       = 32'd0;
            read_addres1    = _read_addres1;
            read_addres2    = 32'd0;
            inst_exp1       = _inst_exp1;
            inst_exp2       = 12'd0;
            // delay_slot_out1 = in_delay_slot_without_rst;
        end 
        else begin
            // 可以取两条数据
            read_data1       = _read_data1;
            read_data2       = _read_data2;
            read_addres1    = _read_addres1;
            read_addres2    = _read_addres2;
            inst_exp1       = _inst_exp1;
            inst_exp2       = _inst_exp2;
            // delay_slot_out1 = in_delay_slot_without_rst;
        end
    end

    // always_ff @(posedge clk) begin : update_in_delay_slot_without_rst
    //     if(fifo_rst)
    //         in_delay_slot_without_rst <= 1'd0;
    //     else if(master_is_branch && read_en1) begin
    //         in_delay_slot_without_rst <= 1'd1;
    //     end
    //     else if(read_en1)
    //         in_delay_slot_without_rst <= 1'd0;
    // end

    // always_ff @(posedge clk) begin : update_delayed
    //     if(fifo_rst && rst_with_delay) begin
    //         in_delay_slot   <= 1'd1;
    //         delayed_data    <= (read_pointer + 4'd1 == write_pointer || read_pointer == write_pointer)? write_data1 : data[read_pointer + 4'd1]; // XXX 为什么不是就赋值后面那一个
    //         delayed_pc      <= (read_pointer + 4'd1 == write_pointer || read_pointer == write_pointer)? write_address1 : address[read_pointer + 4'd1];
    //         delayed_inst_exp<= (read_pointer + 4'd1 == write_pointer || read_pointer == write_pointer)? write_inst_exp1 : inst_exp[read_pointer + 4'd1];
    //     end
    //     else if(delay_slot_refill && write_en1) begin
    //         delayed_data    <= write_data1;
    //         delayed_inst_exp<= write_inst_exp1;
    //     end
    //     else if(!delay_slot_refill && read_en1) begin
    //         in_delay_slot   <= 1'd0;
    //         delayed_data    <= 32'd0;
    //         delayed_pc      <= 32'd0;
    //         delayed_inst_exp<= 12'd0;
    //     end
    // end

    always_ff @(posedge clk) begin : update_write_pointer
        if(fifo_rst)
            write_pointer <= 4'd0;
        else if(write_en1 && write_en2)
            write_pointer <= write_pointer + 4'd2;
        else if(write_en1)
            write_pointer <= write_pointer + 4'd1;
    end

    always_ff @(posedge clk) begin : update_read_pointer
        if(fifo_rst)
            read_pointer <= 4'd0;
        else if(empty)
            read_pointer <= read_pointer;
        else if(read_en1 && read_en2)
            read_pointer <= read_pointer + 4'd2;
        else if(read_en1)
            read_pointer <= read_pointer + 4'd1;
    end

    always_ff @(posedge clk) begin : update_counter
        if(fifo_rst)
            data_count <= 4'd0;
        else if(empty) begin
            // 只写不读
            case({write_en1, write_en2})
            2'b10: begin
                data_count  <= data_count + 4'd1;
            end
            2'b11: begin
                data_count  <= data_count + 4'd2;
            end
            default:
                data_count  <= data_count;
            endcase
        end
        else begin
        // 有写有读，且写优先，1优先 ==>{11,10,00}{11,10,00}
            case({write_en1, write_en2, read_en1, read_en2})
            4'b1100: begin
                data_count  <= data_count + 4'd2;
            end
            4'b1110, 4'b1000: begin
                data_count  <= data_count + 4'd1;
            end
            4'b1011, 4'b0010: begin
                data_count  <= data_count - 4'd1;
            end
            4'b0011: begin
                data_count  <= data_count == 4'd1 ? 4'd0 : data_count - 4'd2;
            end
            default:
                data_count  <= data_count;
            endcase
        end
    end

    // 写入数据更新
    always_ff @(posedge clk) begin : write_data 
        if(~rst & write_en1) begin
            data[write_pointer] <= write_data1;
            address[write_pointer] <= write_address1;
            inst_exp[write_pointer] <= write_inst_exp1;
        end
        if(~rst & write_en2) begin
            data[write_pointer + 4'd1] <= write_data2;
            address[write_pointer + 4'd1] <= write_address2;
            inst_exp[write_pointer + 4'd1] <= write_inst_exp1; // EXP (I)
        end
    end

endmodule