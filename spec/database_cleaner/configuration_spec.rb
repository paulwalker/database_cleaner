require File.dirname(__FILE__) + '/../spec_helper'
require 'database_cleaner/active_record/transaction'
require 'database_cleaner/data_mapper/transaction'


describe DatabaseCleaner do

  describe ActiveRecord do
    describe "connections" do
      it "should return an array of classes containing ActiveRecord::Base by default" do
        ::DatabaseCleaner::ActiveRecord.connection_klasses.should == [::ActiveRecord::Base]
      end
      it "should merge in an array of classes to get connections from" do
        model = mock("model")
        ::DatabaseCleaner::ActiveRecord.connection_klasses = [model]
        ::DatabaseCleaner::ActiveRecord.connection_klasses.should include model
        ::DatabaseCleaner::ActiveRecord.connection_klasses.should include ::ActiveRecord::Base
      end
    end    
  end

  # These examples muck around with the constants for autodetection so we need to clean up....
  before(:all) do
    TempAR = ActiveRecord unless defined?(TempAR)
    TempMM = MongoMapper unless defined?(TempMM)
    Object.send(:remove_const, 'MongoMapper') if defined?(::MongoMapper)
    # need to add one for each ORM that we load in the spec helper...
  end
  after(:all) do
    Object.send(:remove_const, 'ActiveRecord') if defined?(::ActiveRecord) #want to make sure we have the real one...
    ActiveRecord = TempAR
    MongoMapper = TempMM
  end

  before(:each) do
    DatabaseCleaner::ActiveRecord::Transaction.stub!(:new).and_return(@strategy = mock('strategy'))
    Object.const_set('ActiveRecord', "just mocking out the constant here...") unless defined?(::ActiveRecord)
    DatabaseCleaner.strategy = nil
    DatabaseCleaner.orm = nil
  end
  
  describe ".create_strategy" do
    it "should initialize and return the appropirate strategy" do
      DatabaseCleaner::ActiveRecord::Transaction.should_receive(:new).with('options' => 'hash')
      result = DatabaseCleaner.create_strategy(:transaction, {'options' => 'hash'})
      result.should == @strategy
    end
  end

  describe ".clean_with" do
    it "should initialize the appropirate strategy and clean with it" do
      DatabaseCleaner::ActiveRecord::Transaction.should_receive(:new).with('options' => 'hash')
      @strategy.should_receive(:clean)
      DatabaseCleaner.clean_with(:transaction, 'options' => 'hash')
    end
  end

  describe ".strategy=" do
    it "should initialize the appropirate strategy based on the ORM adapter detected" do
      DatabaseCleaner::ActiveRecord::Transaction.should_receive(:new).with('options' => 'hash')
      DatabaseCleaner.strategy = :transaction, {'options' => 'hash'}

      Object.send(:remove_const, 'ActiveRecord')
      Object.const_set('DataMapper', "just mocking out the constant here...")
      DatabaseCleaner.orm = nil

      DatabaseCleaner::DataMapper::Transaction.should_receive(:new).with(no_args)
      DatabaseCleaner.strategy = :transaction
    end

    it "should raise an error when no ORM is detected" do
      Object.send(:remove_const, 'ActiveRecord') if defined?(::ActiveRecord)
      Object.send(:remove_const, 'DataMapper') if defined?(::DataMapper)
      Object.send(:remove_const, 'CouchPotato') if defined?(::CouchPotato)

      running { DatabaseCleaner.strategy = :transaction }.should raise_error(DatabaseCleaner::NoORMDetected)
    end

    it "should use the strategy version of the ORM specified with #orm=" do
      DatabaseCleaner.orm = 'data_mapper'
      DatabaseCleaner::DataMapper::Transaction.should_receive(:new)

      DatabaseCleaner.strategy = :transaction
    end

    it "should raise an error when multiple args is passed in and the first is not a symbol" do
      running { DatabaseCleaner.strategy=Object.new, {:foo => 'bar'} }.should raise_error(ArgumentError)
    end

    it "should raise an error when the specified strategy is not found" do
      running { DatabaseCleaner.strategy = :foo }.should raise_error(DatabaseCleaner::UnknownStrategySpecified)
    end

    it "should allow any object to be set as the strategy" do
      mock_strategy = mock('strategy')
      running { DatabaseCleaner.strategy = mock_strategy }.should_not raise_error
    end

  end


    %w[start clean].each do |strategy_method|
      describe ".#{strategy_method}" do
        it "should be delgated to the strategy set with strategy=" do
          DatabaseCleaner.strategy = :transaction

          @strategy.should_receive(strategy_method)

          DatabaseCleaner.send(strategy_method)
        end

        it "should raise en error when no strategy has been set" do
          running { DatabaseCleaner.send(strategy_method) }.should raise_error(DatabaseCleaner::NoStrategySetError)
        end
      end
    end

end
