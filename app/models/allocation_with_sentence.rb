# This class is a 'presenter' designed to prevent clients having to know whether
# a field lives in the allocation or sentence details when both are returned
# e.g. PrisonerOffenderManagerService#get_allocated_offenders
#
class AllocationWithSentence
  delegate :last_name, :full_name, :earliest_release_date,
           :sentence_start_date, to: :@sentence
  delegate :updated_at, :nomis_offender_id, :primary_pom_allocated_at,
           :responsibility, :allocated_at_tier, to: :@allocation

  def initialize(allocation, sentence)
    @allocation = allocation
    @sentence = sentence
  end

  def new_case?
    @allocation.updated_at >= 7.days.ago
  end
end