`timescale 1ns / 1ps

module tb_alu();

    logic [31:0] a;
    logic [31:0] b;
    logic [3:0] operation;
    logic [31:0] result;

    alu DUT (
    
        .a(a),
        .b(b),
        .operation(operation),
        .result(result)
    
    );
    
    //TASKS
    
        //check task
        task check(input string label, input logic [31:0] got, input logic [31:0] expected);
    
            if(got === expected)
                $display("PASS %s (time: %0t)", label, $time);
            else
                $display("FAIL %s - got %0d, expected %0d (time: %0t)", label, got, expected, $time);
        endtask

    //SVA
    
    
    initial begin
    
        //initialize inputs
        a = 32'b0; b = 32'b0; operation = 4'b0;
        #10;
    
        /*
            Corner caes to cover:
            
                1. Overflow add (test vector chosen as a signed overflow, ADD itself is sign neutral)
                2. Overflow sub (test vector chosen as a signed overflow, SUB itself is sign neutral)
                3. sll by 31 (b = 11111) , original bit 0 must shift all the way to bit 31         
                4. slt signed ( -1 < 5 ) we check if result is 1
                5. sltu (unsigned) a gets unsigned , so the previous -1 of slt, is going to be ~4 billion (~4 billion < 5) the result must be 0
                6. srl by 31 (b = 11111) , original bit 31 must shift all the way to bit 0 
                7. sra: we check if msb (sign bit) gets copied
                8. sent an invalid operation, result must be 0
                9. in any shift, we choose sra, we sent b = 32, but shift must not happen, same with 32 multipliers
                
        */
        
        $display("");
        $display("RISC-V ALU TESTBENCH");        
    
        //TC1: Overflow add
    
        a = 32'b0111_1111_1111_1111_1111_1111_1111_1111; b = 32'b1; operation =  4'b0000;
        #10;
        
        check("TC1 - Overflow add produces the biggest negative 32-bit result", result, 32'b1000_0000_0000_0000_0000_0000_0000_0000);
        
        
        //TC2: Overflow sub
        
        a = 32'b1000_0000_0000_0000_0000_0000_0000_0000; b = 32'b1; operation =  4'b1000;
        #10;         
    
        check("TC2 - Overflow sub produces the biggest positive 32-bit result", result, 32'b0111_1111_1111_1111_1111_1111_1111_1111);
    
    
        //TC3: sll by 31  
    
        a = 32'b0111_1111_1111_1111_1111_1111_1111_1111; b = 32'b11111; operation =  4'b0001;
        #10;        
    
        check("TC3 - sll original a[0] shifted all the way to a[31] ", result, 32'b1000_0000_0000_0000_0000_0000_0000_0000);
    
        
        //TC4: slt signed (-1 < 5), result must be HIGH
        
        a = 32'b1111_1111_1111_1111_1111_1111_1111_1111; b = 32'b101; operation =  4'b0010;
        #10;    

        check("TC4 - slt signed (-1 < 5) result is HIGH", result, 32'b1);


        //TC5: sltu unsigned (~4 billion < 5), result must be HIGH

                                                         b = 32'b101; operation =  4'b0011;
        #10;    

        check("TC5 - sltu unsigned (~4 billion < 5) result is LOW", result, 32'b0);


        //TC6: srl by 31  
    
        a = 32'b1000_0000_0000_0000_0000_0000_0000_0000; b = 32'b11111; operation =  4'b0101;
        #10;        
    
        check("TC6 - srl original a[31] shifted all the way to a[0] ", result, 32'b0000_0000_0000_0000_0000_0000_0000_0001);


        //TC7: sra, sign bit must be copied  
    
        a = 32'b1000_0000_0000_0000_0000_0000_0000_0000; b = 32'b11111; operation =  4'b1101;
        #10;        
    
        check("TC7 - sign bit (1) got copied all the way in sra", result, 32'b1111_1111_1111_1111_1111_1111_1111_1111);


        //TC8: sent an invalid operation  
    
        operation =  4'b1111;
        #10;        
    
        check("TC8 - invalid operation, result is 0", result, 32'b0);


        //TC6: sra by 32 shifting, then sending another 32 multiplier (64), result must be no shift  
    
        a = 32'b1000_0000_0000_0000_0000_0000_0000_0000; b = 32'd32; operation =  4'b1101;
        #10;        
    
        check("TC9a - 32 multipliers shifters dont get the operand shifted, 32 passed", result, 32'b1000_0000_0000_0000_0000_0000_0000_0000);

        b = 32'd64;
        #10;

        check("TC9b - 32 multipliers shifters dont get the operand shifted, 64 passed", result, 32'b1000_0000_0000_0000_0000_0000_0000_0000);
    
        $display("END OF RISC-V ALU TESTBENCH"); 
        $display("");
        
        $finish;
    end

endmodule
