// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
// import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "topbar";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

// import uPlot from "uplot";

function els() {
  const rects = Array.from(document.querySelectorAll("rect[data-project]"));
  const projects = Array.from(document.querySelectorAll("li[data-project]"));
  const branches = Array.from(document.querySelectorAll("li[data-branch]"));
  const files = Array.from(document.querySelectorAll("li[data-file]"));
  return { rects, projects, branches, files };
}

function onProjectHover() {
  // const { rects, projects, branches, files } = els();
  // projects.forEach((p) => {
  //   const project = p.dataset.project;
  //   const otherProjects = projects.filter(
  //     (el) => el.dataset.project != project
  //   );
  //   const otherBranches = branches.filter(
  //     (el) => el.dataset.project != project
  //   );
  //   const otherFiles = files.filter((el) => el.dataset.project != project);
  //   const otherRects = rects.filter((el) => el.dataset.project != project);
  //   p.onmouseenter = () => {
  //     otherProjects.forEach((el) => (el.style.opacity = 0.2));
  //     otherRects.forEach((el) => (el.style.opacity = 0.2));
  //     otherBranches.forEach((el) => (el.style.opacity = 0.2));
  //     otherFiles.forEach((el) => (el.style.opacity = 0.2));
  //   };
  //   p.onmouseleave = () => {
  //     otherProjects.forEach((el) => (el.style.opacity = 1));
  //     otherRects.forEach((el) => (el.style.opacity = 1));
  //     otherBranches.forEach((el) => (el.style.opacity = 1));
  //     otherFiles.forEach((el) => (el.style.opacity = 1));
  //   };
  // });
}

function onBranchHover() {
  // const { rects, projects, branches } = els();
  // branches.forEach((b) => {
  //   const { project, branch } = b.dataset;
  //   const otherProjects = projects.filter(
  //     (el) => el.dataset.project != project
  //   );
  //   const otherBranches = branches.filter(
  //     (el) => el.dataset.branch != branch || el.dataset.project != project
  //   );
  //   const otherRects = rects.filter(
  //     (el) => el.dataset.branch != branch || el.dataset.project != project
  //   );
  //   b.onmouseenter = onmouseenter = () => {
  //     otherProjects.forEach((el) => (el.style.opacity = 0.2));
  //     otherBranches.forEach((el) => (el.style.opacity = 0.2));
  //     otherRects.forEach((el) => (el.style.opacity = 0.2));
  //   };
  //   b.onmouseleave = () => {
  //     otherProjects.forEach((el) => (el.style.opacity = 1));
  //     otherBranches.forEach((el) => (el.style.opacity = 1));
  //     otherRects.forEach((el) => (el.style.opacity = 1));
  //   };
  // });
}

function onFileHover() {
  // const { rects, projects, branches, files } = els();
  // files.forEach((f) => {
  //   const { project, file } = f.dataset;
  //   const otherProjects = projects.filter(
  //     (el) => el.dataset.project != project
  //   );
  //   const otherBranches = branches.filter(
  //     (el) => el.dataset.project != project
  //   );
  //   const otherRects = rects.filter(
  //     (el) => el.dataset.file != file || el.dataset.project != project
  //   );
  //   const otherFiles = files.filter(
  //     (el) => el.dataset.file != file || el.dataset.project != project
  //   );
  //   f.onmouseenter = onmouseenter = () => {
  //     otherBranches.forEach((el) => (el.style.opacity = 0.2));
  //     otherProjects.forEach((el) => (el.style.opacity = 0.2));
  //     otherFiles.forEach((el) => (el.style.opacity = 0.2));
  //     otherRects.forEach((el) => (el.style.opacity = 0.2));
  //   };
  //   f.onmouseleave = () => {
  //     otherBranches.forEach((el) => (el.style.opacity = 1));
  //     otherProjects.forEach((el) => (el.style.opacity = 1));
  //     otherFiles.forEach((el) => (el.style.opacity = 1));
  //     otherRects.forEach((el) => (el.style.opacity = 1));
  //   };
  // });
}

function onRectHover() {
  // const { rects, projects, branches } = els();
  // rects.forEach((r) => {
  //   const { project, branch } = r.dataset;
  //   const otherProjects = projects.filter(
  //     (el) => el.dataset.project != project
  //   );
  //   const otherBranches = branches.filter(
  //     (el) => el.dataset.branch != branch || el.dataset.project != project
  //   );
  //   const otherRects = rects.filter(
  //     (el) => el.dataset.branch != branch || el.dataset.project != project
  //   );
  //   r.onmouseenter = onmouseenter = () => {
  //     otherBranches.forEach((el) => (el.style.opacity = 0.2));
  //     otherProjects.forEach((el) => (el.style.opacity = 0.2));
  //     otherRects.forEach((el) => (el.style.opacity = 0.2));
  //   };
  //   r.onmouseleave = () => {
  //     otherBranches.forEach((el) => (el.style.opacity = 1));
  //     otherProjects.forEach((el) => (el.style.opacity = 1));
  //     otherRects.forEach((el) => (el.style.opacity = 1));
  //   };
  // });
}

const ProjectHighlightHook = {
  mounted() {
    onProjectHover();
  },

  updated() {
    onProjectHover();
  },
};

const BranchHighlightHook = {
  mounted() {
    onBranchHover();
  },

  updated() {
    onBranchHover();
  },
};

const FileHighlightHook = {
  mounted() {
    onFileHover();
  },

  updated() {
    onFileHover();
  },
};

const RectHighlightHook = {
  mounted() {
    onRectHover();
  },
  updated() {
    onRectHover();
  },
};

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    ProjectHighlightHook,
    BranchHighlightHook,
    FileHighlightHook,
    RectHighlightHook,
  },
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", (info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
