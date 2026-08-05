`timescale 1ns / 1ps

module tb_forwarding_unit();

    //DUT Inputs
        logic [4:0] id_ex_rs1;
        logic [4:0] id_ex_rs2;
        logic [4:0] ex_wb_rd;
        logic ex_wb_reg_write;

    //DUT Outputs        
        logic forward_rs1;
        logic forward_rs2;

    //DUT instantiation
    forwarding_unit DUT (
    
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .ex_wb_rd(ex_wb_rd),
        .ex_wb_reg_write(ex_wb_reg_write),
        
        .forward_rs1(forward_rs1),
        .forward_rs2(forward_rs2)

    );


    //Task's

        //check task
        task check (input string label, input logic [31:0] got, input logic [31:0] expected);
    
            if (got === expected)
                $display("PASS %s (time: %0t)", label, $time);
            else
                $error("FAIL %s - got %0d, expected %0d (time: %0t)", label, got, expected, $time);
    
        endtask


    //main stimulus
    initial begin
    
        $display("");
        $display("Start of forwarding_unit testbench:");
        
        //initialize DUT inputs to avoid X's in simulation
        id_ex_rs1 = 5'd0; id_ex_rs2 = 5'd0; ex_wb_rd = 5'd0; ex_wb_reg_write = 0; 
        
        
        /*
            Corner cases to cover:

            Forwarding needs three conditions, so one case per condition failing:

            1. Match: WB writes the register the operand came from: forward.
            2. No match: WB writes a different register: don't forward.
               Without this, a unit ignoring the comparison would still pass 1.
               
            3. reg_write low: stores and branches have an rd field but write nothing.
            4. rd is x0: hardwired to zero, never really written.

            Run for rs1 and rs2 separately, since they compare independently.
        */
        
        
        $display("");
        //TC1(rs1)
        
            ex_wb_reg_write = 1; ex_wb_rd = 5'd5; id_ex_rs1 = 5'd5;  #1;  
            check("TC1(rs1) reg_write = 1, rd and rs1 is x5 - got forward_rs1 = 1", forward_rs1, 1);        
            #5;
        
        //TC2(rs1)
        
            ex_wb_reg_write = 1; ex_wb_rd = 5'd7; id_ex_rs1 = 5'd5;  #1;  
            check("TC2(rs1) reg_write = 1, rd and rs1 are NOT the same - got forward_rs1 = 0", forward_rs1, 0);        
            #5;        
        
        //TC3(rs1)
        
            ex_wb_reg_write = 0; ex_wb_rd = 5'd5; id_ex_rs1 = 5'd5;  #1;  
            check("TC3(rs1) reg_write = 0 (wb not writing), rd and rs1 is x5 - got forward_rs1 = 0", forward_rs1, 0);        
            #5;        
        
        //TC4(rs1)
        
            ex_wb_reg_write = 1; ex_wb_rd = 5'd0; id_ex_rs1 = 5'd0;  #1;  
            check("TC4(rs1) reg_write = 1, rd and rs1 are x0 (harwired to 0) - got forward_rs1 = 0", forward_rs1, 0);        
            #5;              
    

    //SAME TEST CASES FOR rs2:
    

        $display("");
        //TC1(rs2)
        
            ex_wb_reg_write = 1; ex_wb_rd = 5'd5; id_ex_rs2 = 5'd5;  #1;  
            check("TC1(rs2) reg_write = 1, rd and rs2 is x5 - got forward_rs2 = 1", forward_rs2, 1);        
            #5;
        
        //TC2(rs2)
        
            ex_wb_reg_write = 1; ex_wb_rd = 5'd7; id_ex_rs2 = 5'd5;  #1;  
            check("TC2(rs2) reg_write = 1, rd and rs2 are NOT the same - got forward_rs2 = 0", forward_rs2, 0);        
            #5;        
        
        //TC3(rs2)
        
            ex_wb_reg_write = 0; ex_wb_rd = 5'd5; id_ex_rs2 = 5'd5;  #1;  
            check("TC3(rs2) reg_write = 0 (wb not writing), rd and rs2 is x5 - got forward_rs2 = 0", forward_rs2, 0);        
            #5;        
        
        //TC4(rs2)
        
            ex_wb_reg_write = 1; ex_wb_rd = 5'd0; id_ex_rs2 = 5'd0;  #1;  
            check("TC4(rs2) reg_write = 1, rd and rs2 are x0 (harwired to 0) - got forward_rs2 = 0", forward_rs2, 0);        
            #5;              
        $display("");
        
        $display("End of forwarding_unit testbench.");        
        $display("");
        
        $finish;
    end

endmodule
