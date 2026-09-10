# frozen_string_literal: true

class DigestClaimTokens < ActiveRecord::Migration[8.1]
  def up
    # Hash in SQL so existing plaintext values never enter migration diagnostics.
    execute "UPDATE received_events SET claim_token = SHA2(claim_token, 256) WHERE claim_token IS NOT NULL"
    execute "UPDATE processing_attempts SET token = SHA2(token, 256)"
    rename_column :received_events, :claim_token, :claim_token_digest
    rename_column :processing_attempts, :token, :token_digest
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Plaintext claim tokens cannot be recovered from their digests"
  end
end
