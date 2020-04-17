require "rails_helper"

describe Nomis::SentenceDetail, model: true do
  let(:date) { Date.new(2019, 2, 3) }
  let(:override) { Date.new(2019, 5, 3) }

  describe "#automatic_release_date" do
    context "when override present" do
      before do
        subject.automatic_release_date = date
        subject.automatic_release_override_date = override
      end

      it "overrides" do
        expect(subject.automatic_release_date).to eq(override)
      end
    end

    context "without override" do
      before do
        subject.automatic_release_date = date
        subject.automatic_release_override_date = nil
      end

      it "uses original" do
        expect(subject.automatic_release_date).to eq(date)
      end
    end
  end

  describe "#conditional_release_date" do
    context "when override present" do
      before do
        subject.conditional_release_date = date
        subject.conditional_release_override_date = override
      end

      it "overrides" do
        expect(subject.conditional_release_date).to eq(override)
      end
    end

    context "without override" do
      before do
        subject.conditional_release_date = date
      end

      it "uses original" do
        expect(subject.conditional_release_date).to eq(date)
      end
    end
  end

  describe "#nomis_post_recall_release_date" do
    context "when override present" do
      before do
        subject.nomis_post_recall_release_date = date
        subject.nomis_post_recall_release_override_date = override
      end
  
      it "overrides" do
        expect(subject.nomis_post_recall_release_date).to eq(override)
      end
    end
    context "without override" do
      before do
        subject.nomis_post_recall_release_date = date
      end

      it "uses original" do
        expect(subject.nomis_post_recall_release_date).to eq(date)
      end
    end
  end

  describe "#post_recall_release_date" do
    let(:earliest_date) { Date.new(2019, 1, 2) }
    let(:latest_date) { Date.new(2019, 5, 4) }
    let(:no_date) { nil }

    before do
      allow(subject).to receive(:nomis_post_recall_release_date).and_return(nomis_post_recall_release_date)
      subject.actual_parole_date = actual_parole_date
    end

    context "when actual_parole_date comes before post_recall_release_date" do
      let(:actual_parole_date) { earliest_date }
      let(:nomis_post_recall_release_date) { latest_date }

      it "shows actual_parole_date" do
        expect(subject.post_recall_release_date).to eq(earliest_date)
      end
    end
    
    context "when actual_parole_date comes after post_recall_release_date" do
      let(:actual_parole_date) { latest_date }
      let(:nomis_post_recall_release_date) { earliest_date }

      it "shows post_recall_release_date" do
        expect(subject.post_recall_release_date).to eq(earliest_date)
      end
    end

    context "when actual_parole_date and post_recall_release_date are not present" do
      let(:actual_parole_date) { no_date }
      let(:nomis_post_recall_release_date) { no_date }

      it "shows nil" do
        expect(subject.post_recall_release_date).to eq(no_date)
      end
    end
  end
end