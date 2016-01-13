defmodule Cqrs.Repo.Migrations.AddEventsTable do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :uuid, :uuid, [ primary_key: true ]
      add :timestamp, :integer
      add :type, :string
      add :payload, :json
    end
  end

end
