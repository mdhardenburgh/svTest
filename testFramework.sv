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
        virtual function void runFunct();
        endfunction

        // override this in your TEST(...)
        virtual task runTask();
        endtask

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
        function void runAndReportFunction();
            $display("=== RUN   %0s", m_testName);
            runFunction();
            if (failures == 0) 
            begin
                $display("--- PASS  %0s", m_testName);
            end 
            else 
            begin
                $display("--- FAIL  %0s (%0d failure%s)", m_testName, m_failures, (m_failures>1?"s":""));
            end
        endfunction

        // now a task so we can call run() (which may do delays)
        task runAndReportTask();      
            $display("=== RUN   %0s", m_testName);
            runTask();  // ok, run is a task
            if (failures == 0)
            begin
                $display("--- PASS  %0s", m_testName);
            end
            else
            begin
                $display("--- FAIL  %0s (%0d failure%s)", m_testName, failures, (failures>1?"s":""));
            end
        endtask 
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
                    if(str_find(m_tests.m_testName, "_TASK_"))
                    begin
                        m_tests[i].runAndReportTask();
                    end
                    if(str_find(m_tests.m_testName, "_FUNCTION_"))
                    begin
                        m_tests[i].runAndReportFunction();
                    end
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
                if(str_find(m_tests.m_testName, "_TASK_"))
                begin
                    m_tests[i].runAndReportTask();
                end
                if(str_find(m_tests.m_testName, "_FUNCTION_"))
                begin
                    m_tests[i].runAndReportFunction();
                end
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

        function automatic int str_find
        (
            input string  parentString, // haystack
            input string  subString, // needle
            input int     start = 0       // optional starting index (0-based)
        );

            int parentStringLen = parentString.len(); //hlen
            int subStringLen = subString.len(); //nlen
            if (subStringLen == 0) 
                return start <= parentStringLen ? start : -1;
            if (start < 0 || start + subStringLen > parentStringLen) 
                return -1;

            // slide a window of size subStringLen over parentString
            for (int iIter = start; iIter <= parentStringLen - subStringLen; iIter++) 
            begin
                bit match = 1;
                // now go character by character and check if window == subString
                for (int jIter = 0; jIter < subStringLen; jIter++) 
                begin
                    if (parentString.getc(iIter + jIter) != subString.getc(jIter)) 
                    begin
                        match = 0;
                        break;
                    end
                end
                if (match)
                    return iIter;
            end
            return -1;
        endfunction
    endclass

    // Macro to define + register a test case
    `define TEST_FUNCTION(SUITE, NAME)                                
    class SUITE``_FUNCTION_``NAME extends TestCase;                
        function new();
            // call the parent class's constructor 
            super.new(`"`SUITE`.`NAME`"); 
        endfunction 
        virtual function void runFunct();                        

    `define END_TEST_FUNCTION                                          
        endfunction                                          
    endclass                                              
    initial TestManager::register(new SUITE``_FUNCTION_``NAME());   

    // parameterized test case
    `define TEST_FUNCTION_N(SUITE, NAME, WIDTH)                      
    class SUITE``_FUNCTION_``NAME extends TestCase#(WIDTH);
        function new();
            // call the parent class's constructor 
            super.new(`"`SUITE`.`NAME`<`WIDTH`>`"); 
        endfunction
        virtual function void runFunct();

    `define END_TEST_FUNCTION_N
        endfunction
    endclass
    initial TestManager::register(new SUITE``_FUNCTION_``NAME());

    // Macro to define + register a test case
    `define TEST_TASK(SUITE, NAME)                                
    class SUITE``_TASK_``NAME extends TestCase;                
        function new();
            // call the parent class's constructor 
            super.new(`"`SUITE`.`NAME`"); 
        endfunction 
        virtual function void runTask();                        

    `define END_TEST_TASK                                          
        endfunction                                          
    endclass                                              
    initial TestManager::register(new SUITE``_TASK_``NAME());   

    // parameterized test case
    `define TEST_TASK_N(SUITE, NAME, WIDTH)                      
    class SUITE``_TASK_``NAME extends TestCase#(WIDTH);
        function new();
            // call the parent class's constructor 
            super.new(`"`SUITE`.`NAME`<`WIDTH`>`"); 
        endfunction
        virtual function void runTask();

    `define END_TEST_TASK_N
        endfunction
    endclass
    initial TestManager::register(new SUITE``_TASK_``NAME());
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




package testFramework;

  // Base class for every test
  class TestCase #(parameter N = 32);
    string m_testName = "empty";
    int    failures  = 0;

    function new(string name);
      m_testName = name;
      failures   = 0;
    endfunction

    // override this in your TEST(...)
    virtual task run();
      // default: do nothing
    endtask

    // helpers (can stay functions, they don't consume time)
    function void EXPECT_EQ_INT(int a, int b, string msg = "");
      if (a !== b) begin
        $error("[%0s] EXPECT_EQ failed: %s  (got %0d, want %0d)",
               m_testName, msg, a, b);
        failures++;
      end
    endfunction

    /* ... EXPECT_EQ_STR, EXPECT_EQ_LOGIC as before ... 

    // now a task so we can call run() (which may do delays)
    task run_and_report();
      $display("=== RUN   %0s", m_testName);
      run();  // ok, run is a task
      if (failures == 0)
        $display("--- PASS  %0s", m_testName);
      else
        $display("--- FAIL  %0s (%0d failure%s)",
                 m_testName, failures, (failures>1?"s":""));
    endtask
  endclass

  // Manager: holds all registered tests
  class TestManager;
    static TestCase tests[$];
    static int      totalFailures;

    // called by each TEST’s initial block
    static function void register(TestCase tc);
      tests.push_back(tc);
    endfunction

    // call this once from tb to run everything
    static task runAll();
      totalFailures = 0;
      foreach (tests[i]) begin
        tests[i].run_and_report();
        totalFailures += tests[i].failures;
      end
      $display("=== SUMMARY: %0d test%s, %0d failure%s",
               tests.size(), (tests.size()>1?"s":""), 
               totalFailures, (totalFailures>1?"s":""));
      if (totalFailures) $fatal;
    endtask
  endclass

  // Macro to define + register a test case
  `define TEST(SUITE, NAME)                                \
    class SUITE``_``NAME extends TestCase;                  \
      function new();                                       \
        super.new("``SUITE.``NAME");                        \
      endfunction                                           \
      virtual task run();

  `define ENDTEST                                         \
    endtask                                               \
    endclass                                              \
    initial TestManager::register(new SUITE``_``NAME());

  // parameterized TEST_N analogously: make run a task, register it
  /* ... 
endpackage








package my_tests;
  import testFramework::*;

  // simple arithmetic test
  `TEST(Math, Addition)
    // these run inside a task, so we can wait for clocks, etc.
    Start = 1;
    Reset = 1;
    repeat (1) @(posedge clk);

    Reset = 0;
    repeat (N) @(posedge clk);

    EXPECT_EQ_INT(ready, 1, "module should be ready after N cycles");
  `ENDTEST

  // string comparisons still no time needed
  `TEST(Strings, Compare)
    string a = "foo", b = "foo", c = "bar";
    EXPECT_EQ_INT((a==b), 1, "a==b");
    EXPECT_EQ_INT((a==c), 0, "a!=c");
  `ENDTEST
endpackage

// in your top-level testbench:
module tb;
  // clock generation, DUT instantiation, etc.
  initial begin
    my_tests::TestManager::runAll();
  end
endmodule