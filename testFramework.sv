`ifndef TEST_FRAMEWORK
`define TEST_FRAMEWORK
package testFramework;
    
    // Base class for every test
    class TestCase;
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
        function void EXPECT_EQ_LOGIC(logic[31:0] a, logic[31:0] b, string msg="", string format="decimal");
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

        function string getName();
            return m_testName;
        endfunction

        function void setFailures(int concurrentFails);
            m_failures = m_failures + concurrentFails;
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
        task runTaskTest();
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

    class TestCaseParameterized #(parameter N = 32) extends TestCase;

        function new(string name);
            super.new(name);
        endfunction

        // helper: called by TEST body
        function void EXPECT_EQ_LOGIC_N(logic[N-1:0] a, logic[N-1:0] b, string msg="", string format="decimal");
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
                    m_tests[i].runTaskTest();
                    m_tests[i].setFailures(concurrentFailure);
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
                m_tests[i].runTaskTest();
                m_tests[i].setFailures(concurrentFailure);
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
    class SUITE``_``NAME``_FUNCTION_`` extends TestCaseParameterized#(WIDTH); \
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
    class SUITE``_``NAME``_TASK_``WIDTH extends TestCaseParameterized#(WIDTH); \
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
    module SUITE``_CONCURENT_ASSERTIONS`` \
    import testFramework::*;

    `define END_CONCURENT_ASSERTIONS \
    endmodule

    `define CONCURENT_PROPERTY_ERROR(SUITE, NAME) \
    property SUITE``_``NAME``_CONCURENT_PROPERTY_ERROR_P``;

    `define END_CONCURENT_PROPERTY_ERROR(SUITE, NAME) \
    endproperty \
    SUITE``_``NAME``_CONCURENT_PROPERTY_ERROR_A``: assert property(SUITE``_``NAME``_CONCURENT_PROPERTY_ERROR_P``) \
        else \
        begin \
            $error("%s.%s_CONCURENT_ASSERTION FAILED in test: %s", `"SUITE`", `"NAME`", TestManager::getConcurrentTask()); \
            TestManager::setConcurentFailure(); \
        end

    `define END_CONCURENT_PROPERTY_ERROR_PRINT(SUITE, NAME) \
    endproperty \
    SUITE``_``NAME``_CONCURENT_PROPERTY_ERROR_A``: assert property(SUITE``_``NAME``_CONCURENT_PROPERTY_ERROR_P``) \
        else \
        begin \
            $error("%s.%s_CONCURENT_ASSERTION FAILED in test: %s", `"SUITE`", `"NAME`", TestManager::getConcurrentTask()); \
            TestManager::setConcurentFailure();

    `define END_CONCURENT_PROPERTY_ERROR_PRINT_END_PRINT \
        end

endpackage
`endif
