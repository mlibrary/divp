#!/usr/bin/env ruby
# frozen_string_literal: true

# Mutable object for determining what to do with a shipment
class Agenda
  def initialize(shipment, stages)
    @shipment = shipment
    @stages = stages
    # For quick lookup of stages
    @stage_to_index = @stages.map.with_index { |s, i| [s.name.to_sym, i] }.to_h
  end

  def to_s
    "<AGENDA #{agenda}>"
  end

  # Propagate stage errors onto subsequent stages.
  def update(source_stage) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    @stages.each do |stage|
      next if @stage_to_index[stage.name.to_sym] <=
        @stage_to_index[source_stage.name.to_sym]

      if source_stage.fatal_error?
        agenda[stage.name.to_sym] = []
      else
        agenda[stage.name.to_sym].delete_if do |objid|
          source_stage.error_objids.include? objid
        end
      end
    end
  end

  # Stage name -> Array of objids that have had no errors in the current run
  def for_stage(stage)
    agenda[stage.name.to_sym] || []
  end

  def any?
    agenda.any? { |_k, v| v.count.positive? }
  end

  private

  # Called once to create to-do list of objids for each stage.
  # Initialized with any changes to fixity that have occurred since last run.
  def agenda
    return @agenda unless @agenda.nil?

    @agenda = {}
    todo = fixity_changes
    @stages.each do |stage|
      todo.merge @shipment.objids unless stage.complete?
      @agenda[stage.name.to_sym] = todo.to_a.sort
    end
    @agenda
  end

  # Set of objids that have had fixity {added, removed, changed} changes
  def fixity_changes
    changes = Set.new
    fixity = @shipment.fixity_check
    changes.merge fixity[:added].collect(&:objid).compact
    changes.merge fixity[:removed].collect(&:objid).compact
    changes.merge fixity[:changed].collect(&:objid).compact
    changes
  end
end
