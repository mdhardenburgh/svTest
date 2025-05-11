`ifndef TEST_FRAMEWORK
`define TEST_FRAMEWORK
package testFramework;

    // Base class for every test
    class TestCase #(parameter N = 32);
        string m_testName = "empty";
        int m_failures = 0;

        function new(string name);
            m_testName = name;
            m_failures = 0;
        endfunction

        // override this in your TEST(...)
        virtual function void run();
        endfunction

        // helper: called by TEST body
        function void EXPECT_EQ_INT(int a, int b, string msg="");
            if (a !== b) 
            begin
                $error("[%0s] EXPECT_EQ failed: %s  (got %0d, want %0d)", name, msg, a, b);
                m_failures++;
            end
        endfunction

        // helper: called by TEST body
        function void EXPECT_EQ_STR(string a, string b, string msg="");
            if (a != b) 
            begin
                $error("[%0s] EXPECT_EQ failed: %s  (got %s, want %s)", name, msg, a, b);
                m_failures++;
            end
        endfunction
        
        // helper: called by TEST body
        function void EXPECT_EQ_LOGIC(logic[N-1:0] a, logic[N-1:0] b, string msg="", string format="decimal");
            if (a !== b) 
            begin
                if(format == "decimal")
                begin
                    $error("[%0s] EXPECT_EQ failed: %s  (got %0d, want %0d)", name, msg, a, b);
                end
                else if(format == "hex")
                begin
                    $error("[%0s] EXPECT_EQ failed: %s  (got 0x%h, want 0x%h)", name, msg, a, b);
                end
                else if(format == "binary")
                begin
                    $error("[%0s] EXPECT_EQ failed: %s  (got %b, want %b)", name, msg, a, b);
                end
                m_failures++;
            end
        endfunction

        // hook to run & report
        function void runAndReport();
            $display("=== RUN   %0s", m_testName);
            run();
            if (failures == 0) 
            begin
                $display("--- PASS  %0s", m_testName);
            end 
            else 
            begin
                $display("--- FAIL  %0s (%0d failure%s)", m_testName, m_failures, (m_failures>1?"s":""));
            end
        endfunction
    endclass


    // Manager: holds all registered tests
    class TestManager;
        static TestCase m_tests[$];
        static int      m_totalFailures = 0;

        // called by each TEST’s initial block
        static function void register(TestCase tc);
            m_tests.push_back(tc);
        endfunction

        static function void runSpecific(string testName);
            m_totalFailures = 0;
            int found = 0;
            foreach (m_tests[i]) 
            begin
                found = 1;
                if(testName == tests[i].m_testName)
                begin
                    m_tests[i].runAndReport();
                    m_totalFailures += m_tests[i].m_failures;
                    break;
                end
            end
            if(found)
            begin
                summary();
            end
            else
            begin
                $error("TestManager: no test named '%0s' found", targetName);
                $fatal;
            end
        endfunction

        // call this once from tb to run everything
        static function void runAll();
            m_totalFailures = 0;
            foreach (m_tests[i]) 
            begin
                m_tests[i].runAndReport();
                m_totalFailures += m_tests[i].m_failures;
            end
            summary();
        endfunction

        static function void summary()
            $display(
                "=== SUMMARY: %0d test%s, %0d failure%s",
                m_tests.size(),
                (m_tests.size()>1?"s":""), 
                m_totalFailures,
                (m_totalFailures>1?"s":"")
            );
            if (m_totalFailures) $fatal;
        endfunction
    endclass

    // Macro to define + register a test case
    `define TEST(SUITE, NAME)                                
    class SUITE``_``NAME extends TestCase;                
        function new();
            // call the parent class's constructor 
            super.new(`"`SUITE`.`NAME`"); 
        endfunction 
        virtual function void run();                        

    `define ENDTEST                                          
        endfunction                                          
    endclass                                              
    initial TestManager::register(new SUITE``_``NAME());   

    // parameterized test case
    `define TEST_N(SUITE, NAME, WIDTH)                      
    class SUITE``_``NAME extends TestCase#(WIDTH);
        function new();
            // call the parent class's constructor 
            super.new(`"`SUITE`.`NAME`<`WIDTH`>`"); 
        endfunction
        virtual function void run();

    `define ENDTEST_N
        endfunction
    endclass
    initial TestManager::register(new SUITE``_``NAME());
endpackage
/**
//-----------------------------------------------------------------------------
// FILE: my_tests.sv
//-----------------------------------------------------------------------------
`include "test_framework.sv"
import test_fw::*;

package my_tests;

  // a simple test
  `TEST(Math, Addition)
    expect_eq(1+1, 2, "1+1==2");
    expect_eq(2+2, 5, "2+2==5 should fail");
  `ENDTEST

  // another test
  `TEST(Strings, Compare)
    string a = "foo", b = "foo", c = "bar";
    expect_eq((a==b), 1, "a==b");
    expect_eq((a==c), 0, "a!=c");
  `ENDTEST

endpackage

//-----------------------------------------------------------------------------
// FILE: tb.sv
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "test_framework.sv"
`include "my_tests.sv"

import test_fw::*;
import my_tests::*;

module tb;
  initial begin
    // wait 1 timestep so all test-registrations (initials) have run
    #1;  
    TestManager::run_all();
  end
endmodule

package my_tests;
  import testFramework::*;

  `TEST_N(SeqCounter, Basic, 16)
    // ----------------------------------------------------------------
    // TestCase#(WIDTH=N) provides 'N' for both EXPECT_EQ_LOGIC and
    // for sizing your DUT.
    // ----------------------------------------------------------------

    // test‐local parameter
    localparam int m_clockCycle = 10;

    // clock & control signals
    logic clk;
    logic rst;
    logic start;
    logic [N-1:0] count;

    // instantiate DUT, parameterized by WIDTH=N
    SeqCounter #(.WIDTH(N)) dut (
      .clk   (clk),
      .rst   (rst),
      .start (start),
      .count (count)
    );

    // give our test a readable name
    function new();
      super.new("SeqCounter.Basic<" `STRINGIFY(N)`>");
    endfunction

    virtual function void run();
      //---- clock generation ----
      clk = 0;
      fork
        forever #(m_clockCycle/2) clk = ~clk;
      join_none

      //---- apply reset + start ----
      rst   = 1;
      start = 1;
      #(m_clockCycle);       // hold for one full clock
      rst   = 0;
      start = 0;

      //---- wait N clock cycles ----
      repeat (N) @(posedge clk);

      //---- check the counter ----
      EXPECT_EQ_LOGIC(count, N, "count should equal N after N cycles", "decimal");

      //---- tidy up ----
      disable fork;  // stop the clk generator
    endfunction
  `ENDTEST_N

endpackage