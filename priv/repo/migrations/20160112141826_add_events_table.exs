defmodule Cqrs.Repo.Migrations.AddEventsTable do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :uuid, :uuid, [ primary_key: true ]
      add :aggregate_type, :string
      add :aggregate_uuid, :uuid
      add :timestamp, :datetime
      add :type, :string
      add :payload, :json
    end
    create index(:events, [:aggregate_uuid])
  end

end
