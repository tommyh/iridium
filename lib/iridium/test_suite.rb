module Iridium
  # Iridium supports two types of tests right out of the box
  #
  # 1. Integration Tests: These need a running Iridium::Application server
  # 2. Unit Tests: These tests don't need a running app server
  #
  # The tests are meant to be run with the $ iridium test PATH
  # command. 
  #
  # Examples:
  # $ iridium test test/**/*_test.*
  # $ iridium test test/integration/login_test.js
  # $ iridium test test/unit/validation_test.coffee
  #
  # Tests can be written either Coffeescript or Javascript.
  # Iridium handles the compilation from CS to JS for you
  # seamlessly. 
  #
  # == Behind the Scenes ==
  #
  # There are many different things that must happen for all this work
  # for the developer. Starting from the beginning, all coffeescript files
  # need to be compiled into javascript. This yields a directory tree of
  # javascript files. The application itself must be compiled so all the
  # assets available to the different test runners. Once we have all the 
  # javascript files and assets we can proceed to running tests.
  #
  # === Running Unit Tests ===
  #
  # The test process is different for integration tests and unit tests.
  # Unit tests are written for qUnit. Running qUnit test requires a HTML
  # file to load in qunit.js, qunit.css, all the application assets, and 
  # all the the test files. Running a unit test consists of:
  #
  # 1. Generating the proper HTML file to load everything
  # 2. Create a casperjs browser to navigate to that file
  # 3. Use casperjs to scrape the results
  # 4. Report the results
  #
  # === Running Integration Tests ===
  #
  # Integration tests are slightly less complicated. Running an integration
  # test consists of:
  #
  # 1. Start an Iridium::Application server
  # 2. Boot and point casperjs to the running server
  # 3. Casperjs executes the test
  # 4. Shutdown casper
  # 5. Shutdown the test server
  # 6. Report results
  class TestSuite
    attr_accessor :unit_tests, :integration_tests
    attr_reader :app, :files, :results

    def initialize(app, files, options = {})
      @app, @files, @options = app, files, options
      @files = @files.collect do |file|
        file.to_s.gsub app.root.to_s, ''
      end
      @results = []
    end

    def integration_tests
      files.select { |f| f =~ /test\/integration\// }
    end

    def unit_tests
      files - integration_tests
    end

    def runners
      _runners = []
      _runners = unit_tests.each_with_object(_runners) do |file, memo|
        memo << UnitTestRunner.new(app, [file])
      end
      _runners = integration_tests.each_with_object(_runners) do |file, memo|
        memo << IntegrationTestRunner.new(app, [file])
      end
      _runners
    end

    def run
      setup
      run! unless options[:dry_run]
      teardown
    end

    def test_root
      app.root.join('tmp', 'test_root')
    end

    private
    def options
      @options
    end

    def integration_tests?
      integration_tests.size > 0
    end

    def unit_tests?
      unit_tests.size > 0
    end

    def setup
      app.compile
      build_unit_test_directory if unit_tests?
    end

    def teardown

    end

    def build_unit_test_directory
      suite = self

      _pipeline = Rake::Pipeline.build do
        input app.root
        output suite.test_root

        match 'test/**/*.coffee' do
          coffee_script
        end

        match 'test/**/*_test.js' do
          copy
        end

        match "test/support/**/*.js" do
          copy
        end

        site_directory = File.basename(app.site_path)

        match "#{site_directory}/**/*" do
          copy do |path|
            path.sub(%r{^#{site_directory}\/}, '')
          end
        end
      end

      _pipeline.tmpdir = test_root.join('tmp')
      _pipeline.invoke_clean
    end

    def run!
      runners.each do |test|
        test.run
      end
    end
  end
end