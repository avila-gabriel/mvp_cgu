import { Ok, Error } from "./gleam.mjs";

function selectedFile(inputId) {
  const input = document.getElementById(inputId);

  if (!input || !input.files || input.files.length === 0) {
    return new Error("Choose a ZIP file before uploading.");
  }

  return new Ok(input.files[0]);
}

function isZip(file) {
  const name = file.name.toLowerCase();
  return (
    name.endsWith(".zip") ||
    file.type === "application/zip" ||
    file.type === "application/x-zip-compressed"
  );
}

function accessHeaders(accessKey) {
  const headers = { "x-requested-with": "lustre" };

  if (accessKey && accessKey.trim() !== "") {
    headers["x-master-access-key"] = accessKey.trim();
  }

  return headers;
}

export async function upload_file(inputId, endpoint, contentType, accessKey, callback) {
  const selected = selectedFile(inputId);

  if (selected instanceof Error) {
    callback(selected);
    return;
  }

  const file = selected[0];
  if (!isZip(file)) {
    callback(new Error("The selected file must be a ZIP."));
    return;
  }

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        ...accessHeaders(accessKey),
        "content-type": contentType,
      },
      body: file,
    });
    const text = await response.text();

    if (response.ok) {
      callback(new Ok(text));
    } else {
      callback(new Error(text || `${response.status} ${response.statusText}`));
    }
  } catch (e) {
    callback(new Error("Could not reach master: " + e.message));
  }
}

export async function fetch_text(endpoint, accessKey, callback) {
  try {
    const response = await fetch(endpoint, {
      headers: accessHeaders(accessKey),
    });
    const text = await response.text();

    if (response.ok) {
      callback(new Ok(text));
    } else {
      callback(new Error(text || `${response.status} ${response.statusText}`));
    }
  } catch (e) {
    callback(new Error("Could not reach master: " + e.message));
  }
}

export async function read_file_as_text(inputId) {
  const input = document.getElementById(inputId);

  if (!input || !input.files || input.files.length === 0) {
    return new Error("Nenhum arquivo selecionado");
  }

  const file = input.files[0];

  // 1. Check extension
  const isCsvExtension = file.name.toLowerCase().endsWith(".csv");

  // 2. Check MIME type (can be empty or unreliable, so we don't trust it alone)
  const isCsvMime =
    file.type === "text/csv" ||
    file.type === "application/vnd.ms-excel";

  if (!isCsvExtension && !isCsvMime) {
    return new Error("O arquivo selecionado não é um CSV");
  }

  try {
    const text = await file.text();
    return new Ok(text);
  } catch (e) {
    return new Error("Erro ao ler o arquivo: " + e.message);
  }
}

function inferImageMimeType(file) {
  const name = file.name.toLowerCase();

  if (name.endsWith(".png")) return "image/png";
  if (name.endsWith(".jpg") || name.endsWith(".jpeg")) return "image/jpeg";
  if (name.endsWith(".webp")) return "image/webp";

  return "";
}

function readAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () =>
      reject(reader.error || new Error("Falha ao ler o arquivo"));
    reader.readAsDataURL(file);
  });
}

export async function read_file_as_data_url(inputId) {
  const input = document.getElementById(inputId);

  if (!input || !input.files || input.files.length === 0) {
    return new Error("Nenhum arquivo selecionado");
  }

  const file = input.files[0];
  const mimeType = file.type || inferImageMimeType(file);

  if (!mimeType || !mimeType.startsWith("image/")) {
    return new Error("Selecione uma imagem válida");
  }

  try {
    const dataUrl = await readAsDataUrl(file);
    return new Ok([dataUrl, mimeType]);
  } catch (e) {
    return new Error("Erro ao ler o arquivo: " + e.message);
  }
}
