module cp_rem #(
    parameter N_FFT = 128 ,
    parameter CP_LEN = 32 ,
    parameter WIDTH = 16
) (
    input clk ,
    input rst_n ,

    input valid_in ,
    input signed [WIDTH - 1  : 0] in_real ,
    input signed [WIDTH  -1  :0  ] in_img ,

    output signed [WIDTH -1 : 0] out_real ,
    output signed [WIDTH -1  : 0  ] out_img ,
    output reg valid_out
);

    parameter size = $clog2(CP_LEN + N_FFT) ;

    reg [size -1 : 0] idx  ; 


    assign out_real = in_real ;
    assign out_img = in_img  ;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            idx <= 0 ; 
            valid_out<= 0 ; 
        end else if(valid_in )begin
            idx <= idx + 1 ; 
            if(idx < CP_LEN -1 ) begin
                valid_out <= 0 ; 
            end else if (idx == CP_LEN + N_FFT -1)begin
                valid_out <=  0  ; 
                idx <= 0 ;
            end else begin
                valid_out <= 1 ;
            end
        end else begin
            valid_out <= 0 ;
        end
        
    end  
endmodule