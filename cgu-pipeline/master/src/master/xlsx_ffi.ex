defmodule Master.XlsxFfi do
  @target_sheet "Informações Gerais STA"

  def parse_zip(archive) do
    with {:ok, files} <- extract_zip(archive),
         workbooks <- Enum.filter(files, &xlsx_entry?/1),
         :ok <- require_workbooks(workbooks),
         {:ok, parsed} <- parse_workbooks(workbooks) do
      {:ok, parsed}
    else
      {:error, reason} -> {:error, to_string(reason)}
    end
  rescue
    error -> {:error, Exception.message(error)}
  catch
    kind, reason -> {:error, inspect({kind, reason})}
  end

  defp extract_zip(archive) do
    case :zip.extract(archive, [:memory]) do
      {:ok, files} -> {:ok, files}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp xlsx_entry?({name, _body}) do
    name
    |> to_string()
    |> String.downcase()
    |> String.ends_with?(".xlsx")
  end

  defp require_workbooks([]), do: {:error, "zip does not contain any .xlsx files"}
  defp require_workbooks(_workbooks), do: :ok

  defp parse_workbooks(workbooks) do
    Enum.reduce_while(workbooks, {:ok, []}, fn {name, body}, {:ok, acc} ->
      case parse_workbook(name, body) do
        {:ok, rows} -> {:cont, {:ok, [{to_string(name), rows} | acc]}}
        {:error, reason} -> {:halt, {:error, "#{to_string(name)}: #{reason}"}}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      error -> error
    end
  end

  defp parse_workbook(_name, body) do
    with {:ok, package} <- XlsxReader.open(body, source: :binary),
         {:ok, sheet_name} <- target_sheet(package),
         {:ok, rows} <-
           XlsxReader.sheet(package, sheet_name,
             type_conversion: false,
             blank_value: "",
             empty_rows: false
           ) do
      {:ok, Enum.map(rows, &string_row/1)}
    else
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  defp target_sheet(package) do
    sheet_names = XlsxReader.sheet_names(package)

    cond do
      @target_sheet in sheet_names ->
        {:ok, @target_sheet}

      length(sheet_names) == 1 ->
        {:ok, List.first(sheet_names)}

      true ->
        {:error,
         "workbook must contain #{@target_sheet} or exactly one worksheet; found #{Enum.join(sheet_names, ", ")}"}
    end
  end

  defp string_row(row) do
    Enum.map(row, &cell_to_string/1)
  end

  defp cell_to_string(nil), do: ""
  defp cell_to_string(value) when is_binary(value), do: value
  defp cell_to_string(value), do: to_string(value)
end
