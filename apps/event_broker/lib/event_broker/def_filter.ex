defmodule EventBroker.DefFilter do
  @moduledoc """
  I contain the deffilter macro. Require or use me to use deffilter.
  """

  defmacro __using__(_opts) do
    quote do
      import EventBroker.DefFilter
    end
  end

  @doc """
  I am the deffilter macro, permitting inline succinct filter
  definitions.  I take a module name (which becomes a child of the
  current module, e.g.  deffilter Trivial inside EventBroker.Filters
  defines EventBroker.Filters.Trivial), and a do-block containing case
  patterns against which the event is matched and case bodies
  evaluating to true or false.

  My optional parameters are parameter fields for the filter, annotated
  with their expected types.
  """

  defmacro deffilter(filter_name, fields \\ [], do: filter_body) do
    module_fields =
      fields
      |> Enum.map(fn
        {field, type} ->
          quote do
            {unquote(field), unquote(type)}
          end

        field ->
          quote do: {unquote(field), any()}
      end)

    module_fields_names = Keyword.keys(module_fields)

    scoped_vars =
      module_fields
      |> Enum.map(fn {field, _} ->
        quote do
          var!(unquote(Macro.var(field, nil))) =
            Map.get(var!(filter_instance), unquote(field))

          # suppress unused variable warnings
          _ = var!(unquote(Macro.var(field, nil)))
        end
      end)

    %{module: calling_module} = __CALLER__

    quote do
      defmodule unquote(filter_name) do
        @moduledoc """
        I am the #{inspect(__MODULE__)} filter generated by deffilter in #{inspect(unquote(calling_module))}.
        """
        use EventBroker.Filter

        @typedoc """
        I am the parameter type of the #{inspect(__MODULE__)} filter generated by deffilter in #{inspect(unquote(calling_module))}.
        """
        @type t() :: %__MODULE__{unquote_splicing(module_fields)}

        @enforce_keys unquote(module_fields_names)
        defstruct unquote(module_fields_names)

        @spec filter(EventBroker.Event.t(), t()) :: bool()
        def filter(event, filter_instance) do
          var!(filter_instance) = filter_instance
          # suppress unused variable warnings
          _ = var!(filter_instance)

          unquote_splicing(scoped_vars)

          case event do
            unquote(filter_body)
          end
        end
      end
    end
  end
end