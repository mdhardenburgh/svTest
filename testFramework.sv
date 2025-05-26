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
        virtual function void runFunction();
        endfunction

        // override this in your TEST(...)
        virtual task runTask;
        endtask

        // helper: called by TEST body
        function void EXPECT_EQ_INT(int a, int b, string msg="");
            if (a !== b) 
            begin
                $error("[%0s] EXPECT_EQ failed: %s  (got %0d, want %0d)", m_testName, msg, a, b);
                m_failures++;
            end
        endfunction

        // helper: called by TEST body
        function void EXPECT_EQ_STR(string a, string b, string msg="");
            if (a != b) 
            begin
                $error("[%0s] EXPECT_EQ failed: %s  (got %s, want %s)", m_testName, msg, a, b);
                m_failures++;
            end
        endfunction
        
        // helper: called by TEST body
        function void EXPECT_EQ_LOGIC(logic[N-1:0] a, logic[N-1:0] b, string msg="", string format="decimal");
            if (a !== b) 
            begin
                if(format == "decimal")
                begin
                    $error("[%0s] EXPECT_EQ failed: %s  (got %0d, want %0d)", m_testName, msg, a, b);
                end
                else if(format == "hex")
                begin
                    $error("[%0s] EXPECT_EQ failed: %s  (got 0x%h, want 0x%h)", m_testName, msg, a, b);
                end
                else if(format == "binary")
                begin
                    $error("[%0s] EXPECT_EQ failed: %s  (got %b, want %b)", m_testName, msg, a, b);
                end
                m_failures++;
            end
        endfunction

        function string getName();
            return m_testName;
        endfunction

        function void setFailures(int concurrentFailures)
            m_failures = m_failures + concurrentFailures;
        endfunction

        // hook to run & report
        function void runAndReportFunction();
            $display("=== RUN   %0s", m_testName);
            runFunction();
            if (m_failures == 0) 
            begin
                $display("--- PASS  %0s", m_testName);
            end 
            else 
            begin
                $display("--- FAIL  %0s (%0d failure%s)", m_testName, m_failures, (m_failures>1?"s":""));
            end
        endfunction

        // now a task so we can call run() (which may do delays)
        task runTask();
            $display("=== RUN   %0s", m_testName);
            runTask();  // ok, run is a task
        endtask

        task reportTask();
            if (m_failures == 0)
            begin
                $display("--- PASS  %0s", m_testName);
            end
            else
            begin
                $display("--- FAIL  %0s (%0d failure%s)", m_testName, m_failures, (m_failures>1?"s":""));
            end
        endtask
    endclass

    // Manager: holds all registered tests
    class TestManager;
		static TestCase m_tests[$];
    	static int m_totalFailures = 0;
        static string concurrentTask = "";
        static int concurrentFailure = 0;

        // called by each TEST’s initial block
        static function void register(TestCase tc);
            m_tests.push_back(tc);
        endfunction

        static function string getConcurrentTask();
            return concurrentTask;
        endfunction

        static function void setConcurentFailure();
            concurrentFailure++;
        endfunction 

        static function void runSpecificFunction(string testName);
			int found;
            m_totalFailures = 0;
            found = 0;
            foreach (m_tests[i]) 
            begin
                found = 1;
                if(testName == m_tests[i].m_testName)
                begin
                    m_tests[i].runAndReportFunction();
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
                $error("TestManager: no test named '%0s' found", testName);
                $fatal;
            end
        endfunction

        static task runSpecificTask(string testName);
			int found;
            m_totalFailures = 0;
            found = 0;
            foreach (m_tests[i]) 
            begin
                found = 1;
                if(testName == m_tests[i].m_testName)
                begin
                    concurrentTask = m_tests[i].getName();
                    m_tests[i].runTask();
                    m_tests[i].concurrentFailures(concurrentFailure);
                    m_tests[i].reportTask();
                    concurrentFailure = 0; // reset concurrentFailure at the end of the task
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
                $error("TestManager: no test named '%0s' found", testName);
                $fatal;
            end
        endtask

        // call this once from tb to run everything
        static task runAllTasks();
            m_totalFailures = 0;
            foreach (m_tests[i]) 
            begin
                concurrentTask = m_tests[i].getName();
                m_tests[i].runTask();
                m_tests[i].concurrentFailures(concurrentFailure);
                m_tests[i].reportTask();
                concurrentFailure = 0; // reset concurrentFailure at the end of the task
                m_totalFailures += m_tests[i].m_failures;
            end
            summary();
        endtask
        static function void runAllFunctions();
            m_totalFailures = 0;
            foreach (m_tests[i]) 
            begin
                m_tests[i].runAndReportFunction();
                m_totalFailures += m_tests[i].m_failures;
            end
            summary();
        endfunction

        static function void summary();
            $display("=== SUMMARY: %0d test%s, %0d failure%s",
                m_tests.size(),
                (m_tests.size()>1?"s":""), 
                m_totalFailures,
                (m_totalFailures>1?"s":"")
            );
            if (m_totalFailures) $fatal;
        endfunction
    endclass

    // Macro to define + register a test case
    `define TEST_FUNCTION(SUITE, NAME) \
    class SUITE``_``NAME``_FUNCTION_`` extends TestCase; \
        function new(); \
            super.new($sformatf("%s.%s_FUNCTION", `"SUITE`", `"NAME`")); \
        endfunction \
        virtual function void runFunct(); 

    `define END_TEST_FUNCTION(SUITE, NAME) \
        endfunction \
    endclass \
    initial \
    begin \
        SUITE``_``NAME``_FUNCTION tc = new(); \
        TestManager::register(tc); \
    end

    // parameterized test case
    `define TEST_FUNCTION_N(SUITE, NAME, WIDTH) \
    class SUITE``_``NAME``_FUNCTION_`` extends TestCase#(WIDTH); \
        function new(); \
            super.new($sformatf("%s.%s_FUNCTION_%s", `"SUITE`", `"NAME`",`"WIDTH`")); \
        endfunction \
        virtual function void runFunct();

    `define END_TEST_FUNCTION_N(SUITE, NAME, WIDTH) \
        endfunction \
    endclass \
    initial \
    begin \
        SUITE``_``NAME``_FUNCION_``WIDTH tc = new(); \
        TestManager::register(tc); \
    end

    // Macro to define + register a test case
	`define TEST_TASK(SUITE, NAME) \
    class SUITE``_``NAME``_TASK extends TestCase; \
        function new(); \
            super.new($sformatf("%s.%s_TASK", `"SUITE`", `"NAME`")); \
        endfunction \
        virtual task runTask;

    `define END_TEST_TASK(SUITE, NAME) \
		endtask \
    endclass \
    initial \
    begin \
        SUITE``_``NAME``_TASK tc = new(); \
        TestManager::register(tc); \
    end

    // parameterized test case
    `define TEST_TASK_N(SUITE, NAME, WIDTH) \
    class SUITE``_``NAME``_TASK_``WIDTH extends TestCase#(WIDTH); \
        function new(); \
            super.new($sformatf("%s.%s_TASK_%s", `"SUITE`", `"NAME`",`"WIDTH`")); \
        endfunction \
        virtual task runTask;

    `define END_TEST_TASK_N(SUITE, NAME, WIDTH) \
		endtask \
    endclass \
    initial \
    begin \
        SUITE``_``NAME``_TASK_``WIDTH tc = new(); \
        TestManager::register(tc); \
    end

    `define CONCURENT_ASSERTIONS(SUITE) \
    module SUITE``_CONCURENT_ASSERTIONS`` 

    `define END_CONCURENT_ASSERTIONS
    endmodule

    `define CONCURENT_PROPERTY_ERROR(SUITE, NAME) \
    property SUITE``_``NAME``CONCURENT_PROPERTY_ERROR``;

    `define END_CONCURENT_PROPERTY_ERROR(SUITE, NAME) \
    endproperty \
    SUITE``_``NAME``CONCURENT_PROPERTY_ERROR``: assert property(SUITE``_``NAME``CONCURENT_PROPERTY_ERROR``); \
        else \
        begin \
            $error("%s.%s_CONCURENT_ASSERTION FAILED in test: %s", `"SUITE`", `"NAME`", TestManager::getConcurrentTask()); \
            TestManager::setConcurentFailure(); \
        end

endpackage
`endif
<<<<<<< HEAD
=======
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

     ... EXPECT_EQ_STR, EXPECT_EQ_LOGIC as before ... 

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
   ... 
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
*/
>>>>>>> 6ea35c3c964cc6e9fb9c0908f763240911eb8eb9
