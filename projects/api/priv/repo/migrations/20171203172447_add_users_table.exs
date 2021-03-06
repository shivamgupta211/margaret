defmodule Margaret.Repo.Migrations.AddUsersTable do
  @moduledoc false

  use Ecto.Migration

  @doc false
  def change do
    create table(:users) do
      add(:username, :string, size: 64, null: false)
      add(:email, :string, size: 254, null: false)

      add(:unverified_email, :string, size: 254)

      add(:first_name, :string)
      add(:last_name, :string)

      add(:avatar, :string)
      add(:bio, :string)
      add(:website, :string)
      add(:location, :string)

      add(:is_employee, :boolean, default: false, null: false)
      add(:is_admin, :boolean, default: false, null: false)

      add(:deactivated_at, :naive_datetime, default: nil)

      add(:settings, :map, null: false)

      timestamps()
    end

    create(unique_index(:users, [:username]))
    create(unique_index(:users, [:email]))
  end
end
