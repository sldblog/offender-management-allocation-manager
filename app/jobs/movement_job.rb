class MovementJob < ApplicationJob
  queue_as :default

  def perform(mvment)
    MovementService.process_movement(Nomis::Models::Movement.new(JSON.parse(mvment)))
  end
end