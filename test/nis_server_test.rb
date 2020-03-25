require_relative "test_helper"

Yast.import "NisServer"

describe "Yast::NisServer" do
  subject { Yast::NisServer }
  describe "#getMaster" do
    it "returns nil if domain is empty" do
      subject.domain = ""
      expect(subject.getMaster).to eq nil
    end

    it "returns nil if domain directory does not exists" do
      subject.domain = "test"
      allow(Yast::SCR).to receive(:Read).with(path(".target.size"), "/var/yp/test").and_return(-1)

      expect(subject.getMaster).to eq nil
    end

    it "returns nil if domain directory is empty" do
      subject.domain = "test"
      allow(Yast::SCR).to receive(:Read).with(path(".target.size"), "/var/yp/test").and_return(0)
      allow(Yast::SCR).to receive(:Read).with(path(".target.dir"), "/var/yp/test").and_return([])

      expect(subject.getMaster).to eq nil
    end

    it "return master server name" do
      subject.domain = "test"
      allow(Yast::SCR).to receive(:Read).with(path(".target.size"), "/var/yp/test").and_return(0)
      allow(Yast::SCR).to receive(:Read).with(path(".target.dir"), "/var/yp/test").and_return(["a"])
      allow(Yast::SCR).to receive(:Execute)
        .with(
          path(".target.bash_output"),
          "/usr/lib/yp/makedbm -u /var/yp/test/a | grep ^YP_MASTER_NAME")
        .and_return("exit" => 0, "stdout" => "YP_MASTER_NAME expected")

      expect(subject.getMaster).to eq "expected"
    end
  end

  describe "isYPMaster" do
    it "returns false if master is nil" do
      allow(subject).to receive(:getMaster).and_return(nil)

      expect(subject.isYPMaster).to eq false
    end

    it "returns true if master is same as hostname" do
      allow(subject).to receive(:getMaster).and_return("test")
      allow(Yast::SCR).to receive(:Execute)
        .with(
          path(".target.bash_output"),
          "/usr/lib/yp/yphelper --hostname")
        .and_return("exit" => 0, "stdout" => "test")

      expect(subject.isYPMaster).to eq true
    end
  end

  describe "#SaveVariables" do
    context ":slave is passed" do
      it "writes default domain" do
        subject.domain = "test"
        expect(Yast::SCR).to receive(:Write).with(path(".etc.defaultdomain"), "test")

        subject.SaveVariables(:slave)
      end
    end

    context ":master is passed" do
      before do
        allow(Yast::SCR).to receive(:Write)
      end

      it "writes default domain" do
        subject.domain = "test"
        expect(Yast::SCR).to receive(:Write).with(path(".etc.defaultdomain"), "test")

        subject.SaveVariables(:master)
      end

      it "writes variables to /var/yp/Makefile" do
        expect(Yast::SCR).to receive(:Write).with(path(".var.yp.makefile"), nil)

        subject.SaveVariables(:master)
      end
    end
  end
end
