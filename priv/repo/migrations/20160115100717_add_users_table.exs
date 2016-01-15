defmodule Cqrs.Repo.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :uuid, :uuid, [ primary_key: true ]
      add :name, :string
    end
  end

end
