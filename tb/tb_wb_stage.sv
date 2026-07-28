`timescale 1ns / 1ps

module tb_wb_stage();

    //DUT Inputs

        logic reg_write;
        logic  [4:0] rd;  
        logic  [1:0] write_back_src;
        logic [31:0] alu_result;
        logic [31:0] d_mem_read_data;
        logic [31:0] current_pc_plus_4;                 

    //DUT Outputs

        logic out_wb_write_enable;
        logic [4:0] out_wb_rd;
        logic [31:0] out_wb_write_value;

    //DUT instantiation
    wb_stage DUT (
    
        .reg_write(reg_write),
        .rd(rd),
        .write_back_src(write_back_src),
        .alu_result(alu_result),
        .d_mem_read_data(d_mem_read_data),
        .current_pc_plus_4(current_pc_plus_4),
        
        .out_wb_write_enable(out_wb_write_enable),
        .out_wb_rd(out_wb_rd),
        .out_wb_write_value(out_wb_write_value)
        
    );

    
    //Task's

        //check task
        task check (input string label, input logic [31:0] got, input logic [31:0] expected);
    
            //We put === (that can check X's) to test TC4
            if (got === expected)
                $display("PASS %s (time: %0t)", label, $time);
            else
                $error("FAIL %s - got %0d, expected %0d (time: %0t)", label, got, expected, $time);
    
        endtask

    
    //main stimulus
    initial begin

         $display("");
         $display("Start of Write Back (wb_stage) Testbench");

        //initialize DUT inputs to avoid X's in waveform
        reg_write = 0;  
        rd = 5'd0;
        write_back_src = 2'd0;
        alu_result = 32'd0;
        d_mem_read_data = 32'd0;
        current_pc_plus_4 = 32'd0;
        
        /*
            Corner cases to cover:
        
                1. We send ALU result(00) for write_back_src, then we check all 3 outputs of wb 
                2. We send data memory read data(01) for write_back_src, then we check all 3 outputs of wb 
                3. We send PC + 4 return address(11) for write_back_src, then we check all 3 outputs of wb 
        
                For each of these 3 cases, we put reg_write LOW after the checks, to prove that out_wb_write_enable is LOW instantly
                
                4. We send default invalid case(10) for write_back_src, just to test that it hits the default case (X's in waveform for out_wb_write_value)
        
        */
    
        //put values in each input for rd
        alu_result = 32'd694;  d_mem_read_data = 32'd1034;  current_pc_plus_4 = 32'd32; 
        #1;
        
        
        $display("");
        //TC1:
        
            //we want ALU result for rd
            reg_write = 1;  rd = 5'd2;  write_back_src = 2'b00;
            #1;
            check("TC1 reg_write = 1 raised out_wb_write_enable combinationally", out_wb_write_enable, 1);
            check("TC1 rd = x2 returns out_wb_rd = 2 combinationally", out_wb_rd, 5'd2); 
            check("TC1 write_back_src = 00 returned ALU result for out_wb_write_value combinationally", out_wb_write_value, 32'd694);
            
            //we put reg_write LOW to check if out_wb_write_enable is as well LOW instantly
            reg_write = 0; #1;
            check("TC1 reg_write = 0 set out_wb_write_enable = 0 combinationally", out_wb_write_enable, 0);
            
            #10;
            
        //End of TC1    
  
  
        $display("");
        //TC2:
        
            //we want Data memory read data for rd
            reg_write = 1;  rd = 5'd23;  write_back_src = 2'b01;
            #1;
            check("TC2 reg_write = 1 raised out_wb_write_enable combinationally", out_wb_write_enable, 1);
            check("TC2 rd = x23 returns out_wb_rd = 23 combinationally", out_wb_rd, 5'd23); 
            check("TC2 write_back_src = 01 returned data_memory read data for out_wb_write_value combinationally", out_wb_write_value, 32'd1034);
            
            //we put reg_write LOW to check if out_wb_write_enable is as well LOW instantly
            reg_write = 0; #1;
            check("TC2 reg_write = 0 set out_wb_write_enable = 0 combinationally", out_wb_write_enable, 0);
            
            #10; 
            
        //End of TC2    
  
        
        $display("");
        //TC3:
        
            //we want PC + 4 for rd
            reg_write = 1;  rd = 5'd31;  write_back_src = 2'b11;
            #1;
            check("TC3 reg_write = 1 raised out_wb_write_enable combinationally", out_wb_write_enable, 1);
            check("TC3 rd = x31 returns out_wb_rd = 31 combinationally", out_wb_rd, 5'd31); 
            check("TC3 write_back_src = 11 returned current PC + 4 for out_wb_write_value combinationally", out_wb_write_value, 32'd32);
            
            //we put reg_write LOW to check if out_wb_write_enable is as well LOW instantly
            reg_write = 0; #1;
            check("TC3 reg_write = 0 set out_wb_write_enable = 0 combinationally", out_wb_write_enable, 0);
            
            #10;             
            
        //End of TC3
        
        
        $display("");
        //TC4:
        
            //we want dafault invalid case for rd
            reg_write = 1;  rd = 5'd10;  write_back_src = 2'b10;
            #1;
            check("TC4 reg_write = 1 raised out_wb_write_enable combinationally", out_wb_write_enable, 1);
            check("TC4 rd = x10 returns out_wb_rd = 10 combinationally", out_wb_rd, 5'd10);             
            check("TC4 write_back_src = 10 returned dafault invalid case (X's in waveform) for out_wb_write_value combinationally", out_wb_write_value, 32'dx);
                 
            //we put reg_write LOW to check if out_wb_write_enable is as well LOW instantly
            reg_write = 0; #1;
            check("TC4 reg_write = 0 set out_wb_write_enable = 0 combinationally", out_wb_write_enable, 0);
            
            #10;             
            
        //End of TC4        
                
        $display("");
        $display("End of Write Back (wb_stage) Testbench");
        $display("");
    
        $finish;
    end

endmodule
