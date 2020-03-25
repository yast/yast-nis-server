require_relative "test_helper"

class TestClass < Yast::Client
  def initialize
    Yast.include self, "nis_server/routines.rb"
  end
end

describe "RoutinesInclude" do
  subject { TestClass.new }

  describe "#toboolean" do
    it "converts value to boolean" do
      ["true", 1, true].each do |v|
        expect(subject.toboolean(v)).to eq true
      end

      ["false", 0, false].each do |v|
        expect(subject.toboolean(v)).to eq false
      end
    end

    it "returns false for unknown values" do
      [[], {}, nil, :symbol].each do |v|
        expect(subject.toboolean(v)).to eq false
      end
    end
  end
end
