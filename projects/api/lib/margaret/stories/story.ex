defmodule Margaret.Stories.Story do
  @moduledoc """
  The Story schema and changesets.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import EctoEnum, only: [defenum: 3]

  alias __MODULE__

  alias Margaret.{
    Repo,
    Accounts.User,
    Stars.Star,
    Comments.Comment,
    Publications.Publication,
    CollectionStories.CollectionStory,
    Tags.Tag,
    Helpers
  }

  @type t :: %Story{}

  defenum StoryAudience, :story_audience, [:all, :members, :unlisted]
  defenum StoryLicense, :story_license, [:all_rights_reserved, :public_domain]

  schema "stories" do
    # `content` is rich text and contains metadata, so we store it as a map.
    field(:content, :map)
    belongs_to(:author, User)

    # We use a unique hash to identify the story in a slug.
    field(:unique_hash, :string)

    field(:audience, StoryAudience)
    field(:published_at, :naive_datetime)

    field(:license, StoryLicense)

    has_many(:stars, Star)
    has_many(:comments, Comment)

    # Stories can be published under a publication.
    belongs_to(:publication, Publication)

    has_one(:collection_story, CollectionStory)
    has_one(:collection, through: [:collection_story, :collection])

    many_to_many(:tags, Tag, join_through: "story_tags", on_replace: :delete)

    timestamps()
  end

  @doc """
  Builds a changeset for inserting a story.

  ## Examples

      iex> changeset(attrs)
      %Ecto.Changeset{}

  """
  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs) do
    permitted_attrs = ~w(
      content
      author_id
      audience
      publication_id
      published_at
      license
    )a

    required_attrs = ~w(
      content
      author_id
      audience
      license
    )a

    %Story{}
    |> cast(attrs, permitted_attrs)
    |> validate_required(required_attrs)
    |> Helpers.DraftJS.validate_draftjs_data(field: :content)
    |> assoc_constraint(:author)
    |> assoc_constraint(:publication)
    |> Helpers.maybe_put_tags_assoc(attrs)
    |> maybe_put_unique_hash()
  end

  @doc """
  Builds a changeset for updating a story.

  ## Examples

      iex> update_changeset(%Story{}, attrs)
      %Ecto.Changeset{}

  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%Story{} = story, attrs) do
    permitted_attrs = ~w(
      content
      audience
      publication_id
      published_at
      license
    )a

    story
    |> cast(attrs, permitted_attrs)
    |> validate_published_at()
    |> Helpers.DraftJS.validate_draftjs_data(field: :content)
    |> assoc_constraint(:publication)
    |> Helpers.maybe_put_tags_assoc(attrs)
  end

  # After a story gets published, it cannot change its date of publication.
  # We consider a story published when the `published_at` attribute
  # is lesser than the current time.
  @spec validate_published_at(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_published_at(%Ecto.Changeset{data: %Story{published_at: nil}} = changeset) do
    changeset
  end

  defp validate_published_at(%Ecto.Changeset{data: %Story{} = story} = changeset) do
    with :lt <- NaiveDateTime.compare(story.published_at, NaiveDateTime.utc_now()),
         {:ok, _} <- fetch_change(changeset, :published_at) do
      add_error(
        changeset,
        :published_at,
        "Cannot change publication date after the story has been published"
      )
    else
      _ -> changeset
    end
  end

  # Only put `unique_hash` in the changeset if the story is being created.
  @spec maybe_put_unique_hash(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp maybe_put_unique_hash(%Ecto.Changeset{data: %{unique_hash: nil}} = changeset) do
    put_change(changeset, :unique_hash, generate_hash())
  end

  defp maybe_put_unique_hash(changeset), do: changeset

  # Generates a unique hash for a story.
  @spec generate_hash :: String.t()
  defp generate_hash do
    unique_hash_length = 16

    # I think this is enough to guarantee uniqueness.
    :sha512
    |> :crypto.hash(UUID.uuid4())
    |> Base.encode32()
    |> String.slice(0..unique_hash_length)
    |> String.downcase()
  end

  @doc """
  Preloads the author of a story.
  """
  @spec preload_author(t()) :: t()
  def preload_author(%Story{} = story), do: Repo.preload(story, :author)

  @doc """
  Preloads the publication of a story.
  """
  @spec preload_publication(t()) :: t()
  def preload_publication(%Story{} = story), do: Repo.preload(story, :publication)

  @doc """
  Preloads the collection of a story.
  """
  @spec preload_collection(t()) :: t()
  def preload_collection(%Story{} = story), do: Repo.preload(story, :collection)

  @doc """
  Preloads the tags of a story.

  ## Examples

      iex> preload_tags(%Story{})
      %Story{}

  """
  @spec preload_tags(t()) :: t()
  def preload_tags(%Story{} = story), do: Repo.preload(story, :tags)
end
