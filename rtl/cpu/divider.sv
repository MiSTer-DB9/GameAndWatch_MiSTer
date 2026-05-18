module divider (
    input wire clk,
    input wire clk_en,

    input wire reset,

    input wire [3:0] cpu_id,

    input wire reset_gamma,
    input wire [3:0] reset_gamma_mask,
    input wire reset_divider,
    input wire reset_divider_keep_6,
    input wire reset_10ms_counter,

    output reg gamma = 0,
    output reg [3:0] gamma_flags = 0,
    output reg divider_1s_tick = 0, // Temp value to wake from halt

    output wire divider_4hz,
    output wire divider_32hz,
    output wire divider_64hz,
    output wire divider_1khz,
    output reg [3:0] divider_count_10ms = 0,
    output reg [14:0] divider = 0
);
  assign divider_4hz  = divider[14];
  assign divider_32hz = divider[11];
  assign divider_64hz = divider[10];
  assign divider_1khz = divider[4];

  reg [3:0] sm530_count_1s = 0;
  reg [8:0] sm530_subdiv_10ms = 0;

  always @(posedge clk) begin
    if (reset) begin
      case (cpu_id)
        4:       gamma <= 1;  // SM5a
        default: gamma <= 0;  // SM510/SM510 Tiger
      endcase

      divider <= 0;
      gamma_flags <= cpu_id == 4'd4 ? 4'h1 : 4'h0;
      divider_1s_tick <= 0;
      divider_count_10ms <= 0;
      sm530_count_1s <= 0;
      sm530_subdiv_10ms <= 0;
    end else if (clk_en) begin
      reg [14:0] next_divider;
      reg [3:0] next_gamma_flags;

      divider_1s_tick <= 0;
      next_divider = divider + 15'h1;
      next_gamma_flags = gamma_flags;

      if (reset_gamma) begin
        next_gamma_flags = 4'h0;
      end

      if (reset_gamma_mask != 4'h0) begin
        next_gamma_flags = next_gamma_flags & ~reset_gamma_mask;
      end

      if (reset_10ms_counter) begin
        divider_count_10ms <= 0;
      end

      if (reset_divider) begin
        // TODO: Remove. This is to match MAME testing
        // divider <= 2;
        divider <= 0;
        if (cpu_id == 4'd3) begin
          divider_count_10ms <= 0;
          sm530_count_1s <= 0;
          sm530_subdiv_10ms <= 0;
        end
      end else if (reset_divider_keep_6) begin
        reg [14:0] inc_divider;
        // Increment divider as if we were incrementing normally
        inc_divider = divider + 15'h1;

        divider[14:6] <= 0;
        // Grab only the lower 6 bits
        divider[5:0]  <= inc_divider[5:0];
      end else begin
        // Increment
        divider <= next_divider;

        if (cpu_id == 4'd3) begin
          if (next_divider == 15'h0000) begin
            next_gamma_flags[1] = 1;
            divider_1s_tick <= 1;

            sm530_count_1s <= sm530_count_1s == 4'd9 ? 4'd0 : sm530_count_1s + 4'd1;
            if (sm530_count_1s == 4'd9) begin
              next_gamma_flags[0] = 1;
            end
          end

          if ((next_divider & 15'h3FFF) == 15'h0000) begin
            next_gamma_flags[2] = 1;
          end

          if (next_divider[7:0] < 8'd250 && !reset_10ms_counter) begin
            sm530_subdiv_10ms <= sm530_subdiv_10ms == 9'd319 ? 9'd0 : sm530_subdiv_10ms + 9'd1;

            if (sm530_subdiv_10ms == 9'd319) begin
              divider_count_10ms <= divider_count_10ms == 4'd9 ? 4'd0 : divider_count_10ms + 4'd1;
              if (divider_count_10ms == 4'd9) begin
                next_gamma_flags[3] = 1;
              end
            end
          end
        end else if (divider == 15'h7FFF) begin
          // Will wrap to 0 next cycle. 1 second has elapsed
          next_gamma_flags[0] = 1;
          divider_1s_tick <= 1;
        end
      end

      gamma_flags <= next_gamma_flags;
      gamma <= next_gamma_flags[0] | (cpu_id == 4'd3 && next_gamma_flags[1]);
    end
  end

endmodule
