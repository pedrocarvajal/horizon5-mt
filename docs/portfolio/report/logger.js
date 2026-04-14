const STEPS = {
  validate: "validate",
  clean: "clean",
  read: "read",
  transform: "transform",
  export: "export",
  charts: "charts",
  template: "template",
  pdf: "pdf",
  done: "done",
};

export function log(step, message) {
  const timestamp = new Date().toISOString().slice(11, 19);
  console.log(`[${timestamp}] [${step}] ${message}`);
}

export { STEPS };
