export function createBrowserStorage(storage) {
  function get(key) {
    try {
      return storage ? storage.getItem(key) : null;
    } catch {
      return null;
    }
  }

  function set(key, value) {
    try {
      if (storage) storage.setItem(key, value);
      return !!storage;
    } catch {
      return false;
    }
  }

  function remove(key) {
    try {
      if (storage) storage.removeItem(key);
      return !!storage;
    } catch {
      return false;
    }
  }

  function getJson(key) {
    const value = get(key);
    if (value == null) return null;
    try {
      return JSON.parse(value);
    } catch {
      return null;
    }
  }

  function setJson(key, value) {
    try {
      return set(key, JSON.stringify(value));
    } catch {
      return false;
    }
  }

  return Object.freeze({ get, set, remove, getJson, setJson });
}
