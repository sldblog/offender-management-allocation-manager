require 'rails_helper'

describe RecommendationService do
  let(:tierA) {
    build(:offender,
          sentence: HmppsApi::SentenceDetail.new(
            sentence_start_date: Time.zone.today,
            automatic_release_date: Time.zone.today + 15.months)).tap { |o|
      o.load_case_information(build(:case_information, tier: 'A'))
    }
  }
  let(:tierD) {
    build(:offender,
          sentence: HmppsApi::SentenceDetail.new(
            sentence_start_date: Time.zone.today,
            automatic_release_date: Time.zone.today + 10.months)).tap { |o|
      o.load_case_information(build(:case_information, tier: 'D'))
    }
  }

  let(:tierA_and_immigration_case) {
    build(:offender,
          imprisonmentStatus: 'DET', sentence: HmppsApi::SentenceDetail.new).tap { |o|
      o.load_case_information(build(:case_information, tier: 'A'))
    }
  }

  it "can determine the best type of POM for Tier A" do
    expect(described_class.recommended_pom_type(tierA)).to eq(described_class::PROBATION_POM)
  end

  it "can determine the best type of POM for Tier D" do
    expect(described_class.recommended_pom_type(tierD)).to eq(described_class::PRISON_POM)
  end

  it "can determine the best type of POM for an immigration case" do
    expect(described_class.recommended_pom_type(tierA_and_immigration_case)).to eq(described_class::PRISON_POM)
  end
end
