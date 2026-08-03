`timescale 1ns / 1ps 

module tb_branch_unit();

    //DUT inputs
    logic [31:0] alu_result;
    logic branch;
    logic [2:0] funct3;
    
    //DUT outputs
    logic take_branch;

    //DUT instantiation
    branch_unit DUT (
    
        .alu_result(alu_result),    
        .branch(branch),
        .funct3(funct3),
    
        .take_branch(take_branch)
    
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
        $display("Start of branch unit testbench");
        $display("");
        
        //initialize DUT inputs 
        alu_result = 32'd0; branch = 0; funct3 = 3'd0; 
    
        /*
            Corner cases to cover:
        
                1. We raise branch, funct3 = 000 (beq), and we set alu_result = 0: RESULT = take_branch = 1
                2. We raise branch, funct3 = 000 (beq), and we set alu_result = 21 decimal : RESULT = take_branch = 0
                3. We raise branch, funct3 = 001 (bne), and we set alu_result = 45: RESULT = take_branch = 1
                4. We raise branch, funct3 = 001 (bne), and we set alu_result = 0 decimal : RESULT = take_branch = 0
                
                5. We set branch low, we should get take_branch = 0
                6. We raise branch, funct3 = 111 (invalid), we should get take_branch = 0
        
        */
        
        //TC1: 
            
            branch = 1; funct3 = 3'b000; alu_result = 32'd0;    
            #1;
            check("TC1 branch = 1 for beq got take_branch = 1 when alu_result is 0", take_branch, 1);
            #10;
        
        //TC2: 
            
            branch = 1; funct3 = 3'b000; alu_result = 32'd21;    
            #1;
            check("TC2 branch = 1 for beq got take_branch = 0 when alu_result is 21", take_branch, 0);
            #10;    
        
        //TC3: 
            
            branch = 1; funct3 = 3'b001; alu_result = 32'd45;    
            #1;
            check("TC3 branch = 1 for bne got take_branch = 1 when alu_result is 45", take_branch, 1);
            #10;    
        
        //TC4: 
            
            branch = 1; funct3 = 3'b001; alu_result = 32'd0;    
            #1;
            check("TC4 branch = 1 for bne got take_branch = 0 when alu_result is 0", take_branch, 0);
            #10;
        
        //TC5: 
            
            branch = 0; funct3 = 3'b000; alu_result = 32'd0;    
            #1;
            check("TC5 branch = 0 got take_branch = 0", take_branch, 0);
            #10;        
        
        //TC6: 
            
            branch = 1; funct3 = 3'b111; alu_result = 32'd0;    
            #1;
            check("TC6 branch = 1 got take_branch = 0 when funct3 were invalid (111)", take_branch, 0);
            #10;            
                
        $display("");
        $display("End of branch unit testbench");
        $display("");
    
        $finish;
    end

endmodule
