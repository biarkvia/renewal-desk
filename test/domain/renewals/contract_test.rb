require "minitest/autorun"

module Renewals
  class ContractTest < Minitest::Test
    def test_constructor_trims_details_and_protects_their_state
      original = String.new(" Office Internet ")
      contract = build_contract(title: original, counterparty: " Example Telecom ")
      original.replace("Changed outside the contract")

      assert_equal "Office Internet", contract.title
      assert_equal "Example Telecom", contract.counterparty
      assert_equal 1, contract.schedule_revision
      assert_equal Date.new(2026, 12, 1), contract.notice_due_on
      assert contract.open?
      assert_nil contract.decided_at
      refute_respond_to contract, :title=
      assert_raises(FrozenError) { contract.title.replace("Changed") }
      assert_predicate contract.ends_on, :frozen?
    end

    def test_validates_both_details_at_construction
      [ :title, :counterparty ].each do |field|
        [ "  ", "x" * 161, "A\0B", nil ].each do |value|
          error = assert_raises(Errors::InvalidDetails) { build_contract(**{ field => value }) }

          assert_equal field, error.field
          value.nil? ? assert_nil(error.value) : assert_same(value, error.value)
          assert_equal 160, error.maximum
          assert_equal "#{field} must be valid text between 1 and 160 characters", error.message
        end
      end

      assert_equal "x" * 160, build_contract(title: "x" * 160).title
    end

    def test_normalizes_contract_details_to_utf8
      contract = build_contract(
        title: " Datová přípojka ".encode(Encoding::UTF_16LE),
        counterparty: "José".encode(Encoding::ISO_8859_1)
      )

      assert_equal "Datová přípojka", contract.title
      assert_equal "José", contract.counterparty
      assert_equal Encoding::UTF_8, contract.title.encoding
      assert_equal Encoding::UTF_8, contract.counterparty.encoding
    end

    def test_rejects_invalid_or_unconvertible_text_as_a_domain_error
      [ "\xFF", "\xFF".b ].each do |value|
        error = assert_raises(Errors::InvalidDetails) { build_contract(title: value) }

        assert_equal :title, error.field
        assert_same value, error.value
      end
    end

    def test_restores_a_decided_contract_and_its_revision
      decision = String.new("renew")
      contract = build_contract(id: 42, schedule_revision: 3, decision: decision, decided_at: decision_time)
      decision.replace("do_not_renew")

      assert_equal 42, contract.id
      assert_equal 3, contract.schedule_revision
      assert_equal "renew", contract.decision
      assert_predicate contract.decision, :frozen?
      assert_equal decision_time, contract.decided_at
      assert_predicate contract.decided_at, :utc?
      assert_predicate contract.decided_at, :frozen?
    end

    def test_rejects_inconsistent_restored_state
      open_error = assert_raises(Errors::InvalidState) { build_contract(decided_at: decision_time) }
      assert_equal :decided_at, open_error.field
      assert_equal decision_time, open_error.value
      assert_equal "An open contract cannot have a decision timestamp", open_error.message

      decided_error = assert_raises(Errors::InvalidState) { build_contract(decision: "renew") }
      assert_equal :decided_at, decided_error.field
      assert_nil decided_error.value
      assert_equal "A recorded decision requires a timestamp", decided_error.message

      revision_error = assert_raises(Errors::InvalidState) { build_contract(schedule_revision: 0) }
      assert_equal :schedule_revision, revision_error.field
      assert_equal 0, revision_error.value

      id_error = assert_raises(Errors::InvalidState) { build_contract(id: "42") }
      assert_equal :id, id_error.field
      assert_equal "42", id_error.value
    end

    def test_increments_revision_only_when_the_deadline_moves
      contract = build_contract

      contract.update_details(title: "Fiber service")
      assert_equal "Fiber service", contract.title
      assert_equal 1, contract.schedule_revision

      contract.update_details(ends_on: Date.new(2026, 12, 30), notice_days: 29)
      assert_equal Date.new(2026, 12, 1), contract.notice_due_on
      assert_equal 1, contract.schedule_revision

      contract.update_details(notice_days: 30)
      assert_equal Date.new(2026, 11, 30), contract.notice_due_on
      assert_equal 2, contract.schedule_revision
    end

    def test_invalid_update_leaves_the_contract_unchanged
      contract = build_contract

      assert_raises(Errors::InvalidNoticePeriod) { contract.update_details(title: "Changed", notice_days: 366) }

      assert_equal "Office Internet", contract.title
      assert_equal 30, contract.notice_days
      assert_equal 1, contract.schedule_revision
    end

    def test_accepts_both_decisions_even_after_the_notice_deadline
      %w[renew do_not_renew].each do |decision|
        contract = build_contract
        assert contract.due_today?(today: Date.new(2026, 12, 1))
        assert contract.overdue?(today: decision_time.to_date)
        assert contract.due_for_reminder?(today: decision_time.to_date)

        contract.record_decision(decision: decision, decided_at: decision_time)

        refute contract.open?
        refute contract.due_today?(today: Date.new(2026, 12, 1))
        refute contract.overdue?(today: decision_time.to_date)
        refute contract.due_for_reminder?(today: decision_time.to_date)
        assert_equal decision, contract.decision
      end
    end

    def test_rejects_an_invalid_decision_without_changing_state
      contract = build_contract

      error = assert_raises(Errors::InvalidDecision) do
        contract.record_decision(decision: "cancel", decided_at: decision_time)
      end

      assert_equal "cancel", error.value
      assert_equal "Decision must be renew or do_not_renew", error.message
      assert contract.open?
      assert_nil contract.decided_at
    end

    def test_a_decided_contract_rejects_changes_and_second_decisions
      contract = build_contract(id: 42, decision: "renew", decided_at: decision_time)

      update_error = assert_raises(Errors::ContractAlreadyDecided) { contract.update_details(title: "Changed") }
      decision_error = assert_raises(Errors::ContractAlreadyDecided) do
        contract.record_decision(decision: "do_not_renew", decided_at: decision_time)
      end

      [ update_error, decision_error ].each do |error|
        assert_equal 42, error.contract_id
        assert_equal "renew", error.decision
        assert_equal "A renewal decision has already been recorded", error.message
      end
    end

    private

    def build_contract(**attributes)
      defaults = { title: "Office Internet", counterparty: "Example Telecom", ends_on: Date.new(2026, 12, 31), notice_days: 30 }
      Contract.new(**defaults.merge(attributes))
    end

    def decision_time
      Time.new(2026, 12, 2, 12, 0, 0, "+01:00")
    end
  end
end
