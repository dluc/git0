var commit,
    fileElementPrototype;

// -----------------------------------------------------------------------
// Resizable detail / diff split
// -----------------------------------------------------------------------
var initResizeHandle = function() {
	var handle  = document.getElementById('detail-resize-handle');
	var detailPanel = document.getElementById('detail-panel');
	if (!handle || !detailPanel) return;

	var startX, startWidth;

	handle.addEventListener('mousedown', function(e) {
		e.preventDefault();
		startX     = e.clientX;
		startWidth = detailPanel.offsetWidth;
		handle.classList.add('dragging');

		document.addEventListener('mousemove', onMouseMove);
		document.addEventListener('mouseup',   onMouseUp);
	});

	var onMouseMove = function(e) {
		var dx  = e.clientX - startX;
		var newW = startWidth + dx;
		var layout = document.getElementById('layout');
		var minW = 160;
		var maxW = layout ? layout.offsetWidth * 0.6 : 600;
		newW = Math.max(minW, Math.min(newW, maxW));
		detailPanel.style.width = newW + 'px';
	};

	var onMouseUp = function() {
		handle.classList.remove('dragging');
		document.removeEventListener('mousemove', onMouseMove);
		document.removeEventListener('mouseup',   onMouseUp);
	};
};

// -----------------------------------------------------------------------
// Scroll the diff panel to a specific file anchor
// -----------------------------------------------------------------------
var scrollDiffToFile = function(fileId) {
	// Make sure the diff is rendered first
	showDiff();
	var diffPanel = document.getElementById('diff-panel');
	var target    = document.getElementById(fileId);
	if (target && diffPanel) {
		// target.offsetTop is relative to its positioned ancestor;
		// we need offset relative to #diff-panel's scroll container.
		var top = 0;
		var el  = target;
		while (el && el !== diffPanel) {
			top += el.offsetTop;
			el   = el.offsetParent;
		}
		diffPanel.scrollTop = top;
	}
};

// -----------------------------------------------------------------------
// Commit object
// -----------------------------------------------------------------------
var Commit = function(obj) {
	this.object = obj;

	this.refs            = obj.refs();
	this.author_name     = obj.author();
	this.author_email    = obj.authorEmail();
	this.author_date     = obj.authorDate();
	this.committer_name  = obj.committer();
	this.committer_email = obj.committerEmail();
	this.committer_date  = obj.committerDate();
	this.sha             = obj.SHA();
	this.parents         = obj.parents();
	this.subject         = obj.subject();
	this.message         = obj.message();
	this.notificationID  = null;

	this.reloadRefs = function() {
		this.refs = this.object.refs();
	};
};

var extractPrototypes = function() {
	fileElementPrototype = $('file_prototype');
	fileElementPrototype.removeAttribute('id');
	fileElementPrototype.parentNode.removeChild(fileElementPrototype);
};

// -----------------------------------------------------------------------
// Gist
// -----------------------------------------------------------------------
var confirm_gist = function(confirmation_message) {
	if (!Controller.isFeatureEnabled_("confirmGist")) {
		gistie();
		return;
	}

	confirmation_message = confirmation_message || "Yes. Paste this commit.";
	var deleteMessage = Controller.getConfig_("github.token") ? " " : "You might not be able to delete it after posting.<br>";
	var publicMessage = Controller.isFeatureEnabled_("publicGist") ? "<b>public</b>" : "private";
	var notification_text = 'This will create a ' + publicMessage + ' paste of your commit to <a href="https://gist.github.com/">https://gist.github.com/</a><br>' +
		deleteMessage +
		'Are you sure you want to continue?<br/><br/>' +
		'<a href="#" class="cancel">No. Cancel.</a> | ' +
		'<a href="#" class="confirm">' + confirmation_message + '</a>';

	notify(notification_text, 0);
	var notification_message = $("notification_message");
	notification_message.getElementsByClassName("cancel")[0].addEventListener("click", function(e) {
		e.preventDefault();
		hideNotification();
	});
	notification_message.getElementsByClassName("confirm")[0].addEventListener("click", function(e) {
		e.preventDefault();
		gistie();
	});
	$("spinner").classList.add("hidden");
};

var gistie = function() {
	notify("Uploading code to Gistie..", 0);

	var parameters = {public: false, files: {}};
	var filename = commit.object.subject.replace(/[^a-zA-Z0-9]/g, "-") + ".patch";
	parameters.files[filename] = {content: commit.object.patch()};

	var accessToken = Controller.getConfig_("github.token");
	if (Controller.isFeatureEnabled_("publicGist"))
		parameters.public = true;

	var t = new XMLHttpRequest();
	t.onreadystatechange = function() {
		if (t.readyState == 4) {
			var success  = t.status >= 200 && t.status < 300;
			var response = JSON.parse(t.responseText);
			if (success && response.html_url) {
				var a = document.createElement("a");
				a.target   = "_new";
				a.href     = response.html_url;
				a.textContent = response.html_url;
				notify("Code uploaded to " + a.outerHTML, 1);
			} else {
				notify("Pasting to Gistie failed :(.", -1);
				Controller.log_(t.responseText);
			}
		}
	};

	t.open('POST', "https://api.github.com/gists");
	if (accessToken)
		t.setRequestHeader('Authorization', 'token ' + accessToken);
	t.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
	t.setRequestHeader('Accept', 'text/javascript, text/html, application/xml, text/xml, */*');
	t.setRequestHeader('Content-type', 'application/x-www-form-urlencoded;charset=UTF-8');

	try {
		t.send(JSON.stringify(parameters));
	} catch(e) {
		notify("Pasting to Gistie failed: " + e.toString().escapeHTML(), -1);
	}
};

// -----------------------------------------------------------------------
// Gravatar
// -----------------------------------------------------------------------
var setGravatar = function(email, image) {
	image.src = createGravatarUrl(email, image);
};

var createGravatarUrl = function(email, image) {
	if (Controller && !Controller.isFeatureEnabled_("gravatar"))
		return "";
	var gravatarBaseUrl   = "https://www.gravatar.com/avatar/";
	var gravatarParameter = "?d=wavatar&s=60";
	var gravatarID = (email && hex_md5(email.toLowerCase().replace(/ /g, ""))) || "";
	return gravatarBaseUrl + gravatarID + gravatarParameter;
};

// -----------------------------------------------------------------------
// Commit selection helpers
// -----------------------------------------------------------------------
var selectCommit = function(a) {
	Controller.selectCommit_(a);
};

var reload = function() {
	$("notification").classList.add("hidden");
	commit.reloadRefs();
	showRefs();
};

var showRefs = function() {
	var refs = $("refs");
	if (commit.refs) {
		refs.classList.remove("hidden");
		refs.textContent = "";
		for (var i = 0; i < commit.refs.length; i++) {
			var ref  = commit.refs[i];
			var span = document.createElement("span");
			span.classList.add("refs", ref.type());
			if (commit.currentRef == ref.ref)
				span.classList.add("currentBranch");
			span.textContent = ref.shortName();
			refs.appendChild(span);
		}
	} else {
		refs.classList.add("hidden");
	}
};

// -----------------------------------------------------------------------
// loadCommit — called immediately when a commit row is selected
// -----------------------------------------------------------------------
var loadCommit = function(commitObject, currentRef) {
	if (commit && commit.notificationID)
		clearTimeout(commit.notificationID);

	commit              = new Commit(commitObject);
	commit.currentRef   = currentRef;
	commit.fullyLoaded  = false;

	$("commitID").textContent  = commit.sha;
	$("subjectID").textContent = commit.subject;
	$("diff").textContent      = "";
	$("date").textContent      = "";
	$("files").classList.add("hidden");

	// Reset diff panel scroll
	var diffPanel = document.getElementById('diff-panel');
	if (diffPanel) diffPanel.scrollTop = 0;

	var setFormattedEmailContent = function(node, name, email) {
		if (email) {
			node.textContent = name + " <";
			var a   = document.createElement("a");
			a.href  = "mailto:" + email;
			a.textContent = email;
			node.appendChild(a);
			node.appendChild(document.createTextNode(">"));
		} else {
			node.textContent = name;
		}
	};

	setFormattedEmailContent($("authorID"), commit.author_name, commit.author_email);
	$("date").textContent = commit.author_date;
	setGravatar(commit.author_email, $("author_gravatar"));

	if (commit.committer_name != commit.author_name || commit.committer_email != commit.author_email) {
		$("committerID").parentNode.parentNode.classList.remove("hidden");
		setFormattedEmailContent($("committerID"), commit.committer_name, commit.committer_email);
		$("committerDate").textContent = commit.committer_date;
		setGravatar(commit.committer_email, $("committer_gravatar"));
		$("commitDate").parentNode.classList.add("hidden");
	} else if (commit.committer_date != commit.author_date) {
		$("commitDate").parentNode.classList.remove("hidden");
		$("commitDate").textContent = commit.committer_date;
		$("committerID").parentNode.parentNode.classList.add("hidden");
	} else {
		$("committerID").parentNode.parentNode.classList.add("hidden");
		$("commitDate").parentNode.classList.add("hidden");
	}

	var textToHTML = function(txt) {
		return (" " + txt.escapeHTML() + " ")
			.replace(/(https?:\/\/([^\s\.\)\]\<]+|\.[^\s])+)/ig, function(m, url) {
				var a = document.createElement("a");
				a.href = url;
				a.textContent = url;
				return a.outerHTML;
			})
			.replace(/\n/g, "<br>")
			.trim();
	};

	$("message").innerHTML = textToHTML(commit.message);

	jQuery("#commit").show();
	jQuery("#no-commit-message").hide();
	var filelist = $("filelist");
	while (filelist.hasChildNodes())
		filelist.removeChild(filelist.lastChild);
	showRefs();

	// Scroll detail panel to top
	var detailPanel = document.getElementById('detail-panel');
	if (detailPanel) detailPanel.scrollTop = 0;

	var parentsNode = $("parents");
	parentsNode.innerHTML = '';
	if (commit.parents) {
		for (var i = 0; i < commit.parents.length; i++) {
			var container = document.createElement("span");
			container.innerHTML = '<a class="SHA commit-link" href="">' + commit.parents[i].SHA() + "</a>";
			parentsNode.appendChild(container);
		}
		bindCommitSelectionLinks(parentsNode);
	}

	commit.notificationID = setTimeout(function() {
		if (!commit.fullyLoaded)
			notify("Loading commit…", 0);
		commit.notificationID = null;
	}, 500);
};

var showMultipleSelectionMessage = function(messageParts) {
	jQuery("#commit").hide();
	jParagraphs = jQuery.map(messageParts, function(message) {
		return jQuery('<p/>', {text: message});
	});
	jQuery("#no-commit-message").empty().append(jParagraphs).show();
};

// -----------------------------------------------------------------------
// Rename helpers
// -----------------------------------------------------------------------
var commonPrefix = function(a, b) {
	if (a === b) return a;
	var i = 0;
	while (a.charAt(i) == b.charAt(i)) ++i;
	return a.substring(0, i);
};
var commonSuffix = function(a, b) {
	if (a === b) return "";
	var i = a.length - 1, k = b.length - 1;
	while (a.charAt(i) == b.charAt(k)) { --i; --k; }
	return a.substring(i + 1, a.length);
};
var renameDiff = function(a, b) {
	var p = commonPrefix(a, b), s = commonSuffix(a, b),
	    o = a.substring(p.length, a.length - s.length),
	    n = b.substring(p.length, b.length - s.length);
	return [p, o, n, s];
};
var formatRenameDiff = function(d) {
	var p = d[0], o = d[1], n = d[2], s = d[3];
	if (o === "" && n === "" && s === "") return p;
	return [p, "{ ", o, " → ", n, " }", s].join("");
};

// -----------------------------------------------------------------------
// showDiff — renders full diff into area 4
// -----------------------------------------------------------------------
var showDiff = function() {
	if (commit.diffRendered) return;
	commit.diffRendered = true;

	var binaryDiffClass = "display-binary-as-image";
	var binaryDiffHTML  = function(filename) {
		if (filename.match(/\.(png|jpg|icns|psd)$/i)) {
			var a = document.createElement("a");
			a.href = "#";
			a.dataset.filename = filename;
			a.className = binaryDiffClass;
			a.textContent = "Display image";
			return a.outerHTML;
		} else {
			return "Binary file differs";
		}
	};
	var binaryDiffClick = function(e) {
		e.preventDefault();
		return showImage(this, this.dataset.filename);
	};

	highlightDiff(commit.diff, $("diff"), {
		"binaryFileHTML"    : binaryDiffHTML,
		"binaryFileClass"   : binaryDiffClass,
		"binaryFileOnClick" : binaryDiffClick,
	});

	// "Top" links inside the diff area must scroll #diff-panel, not the
	// document (which doesn't scroll — the panel does).
	var diffPanel = document.getElementById('diff-panel');
	var topLinks  = $("diff").querySelectorAll('.top-link a');
	for (var i = 0; i < topLinks.length; i++) {
		topLinks[i].addEventListener('click', function(e) {
			e.preventDefault();
			if (diffPanel) diffPanel.scrollTop = 0;
		});
	}
};

var showImage = function(element, filename) {
	var img = document.createElement("img");
	img.src = "GitX://" + commit.sha + "/" + filename;
	element.outerHTML = img.outerHTML;
	return false;
};

// -----------------------------------------------------------------------
// Feature flags
// -----------------------------------------------------------------------
var enableFeature = function(feature, element) {
	if (!Controller || Controller.isFeatureEnabled_(feature))
		element.classList.remove("hidden");
	else
		element.classList.add("hidden");
};

var enableFeatures = function() {
	enableFeature("gist",     $("gist"));
	enableFeature("gravatar", $("author_gravatar").parentNode);
	enableFeature("gravatar", $("committer_gravatar").parentNode);
};

// -----------------------------------------------------------------------
// loadCommitDiff — called when the backend finishes computing the diff
// -----------------------------------------------------------------------
var loadCommitDiff = function(jsonData) {
	var diffData      = JSON.parse(jsonData);
	commit.filesInfo  = diffData.filesInfo;
	commit.diff       = diffData.fullDiff;
	commit.diffRendered = false;
	commit.fullyLoaded  = true;

	if (commit.notificationID) {
		clearTimeout(commit.notificationID);
	} else {
		$("notification").classList.add("hidden");
	}

	// Build the file list in area 3
	var filelist = $("filelist");
	while (filelist.hasChildNodes())
		filelist.removeChild(filelist.lastChild);

	if (commit.filesInfo.length > 0) {
		for (var i = 0; i < commit.filesInfo.length; i += 1) {
			var fileInfo = commit.filesInfo[i];
			var fileElem = fileElementPrototype.cloneNode(true);
			fileElem.targetFileId = "file_index_" + i;

			var displayName, representedFile;
			if (fileInfo.changeType === "renamed") {
				displayName    = formatRenameDiff(renameDiff(fileInfo.oldFilename, fileInfo.newFilename));
				representedFile = fileInfo.newFilename;
			} else {
				displayName    = fileInfo.filename;
				representedFile = fileInfo.filename;
			}
			fileElem.title = fileInfo.changeType + ": " + displayName;
			fileElem.setAttribute("representedFile", representedFile);

			if (i % 2) fileElem.className += "even";
			else        fileElem.className += "odd";

			// Click → scroll diff panel (area 4) to this file
			fileElem.onclick = function() {
				scrollDiffToFile(this.targetFileId);
			};

			var imgElement      = fileElem.getElementsByClassName("changetype-icon")[0];
			imgElement.src      = "../../images/" + fileInfo.changeType + ".svg";

			var filenameElement = fileElem.getElementsByClassName("filename")[0];
			filenameElement.innerText = displayName;

			var diffstatElem = fileElem.getElementsByClassName("diffstat-info")[0];
			var binaryElem   = fileElem.getElementsByClassName("binary")[0];
			if (fileInfo.binary) {
				diffstatElem.parentNode.removeChild(diffstatElem);
				binaryElem.innerText = fileInfo.oldFileSize + " \u2192 " + fileInfo.newFileSize + " bytes";
			} else {
				binaryElem.parentNode.removeChild(binaryElem);

				var addedWidth   = 2 * fileInfo.numLinesAdded;
				var removedWidth = 2 * fileInfo.numLinesRemoved;
				var maxWidth = 350, minWidth = 5;
				if (addedWidth + removedWidth > maxWidth) {
					var scaleBy = maxWidth / (addedWidth + removedWidth);
					addedWidth   *= scaleBy;
					removedWidth *= scaleBy;
				}
				if (addedWidth   > 0 && addedWidth   < minWidth) addedWidth   = minWidth;
				if (removedWidth > 0 && removedWidth < minWidth) removedWidth = minWidth;

				var numLinesAdded    = fileInfo.numLinesAdded;
				var numLinesRemoved  = fileInfo.numLinesRemoved;
				var numLinesChanged  = numLinesAdded + numLinesRemoved;
				if (numLinesChanged > 999) numLinesChanged = "~" + Math.round(numLinesChanged / 1000) + "k";

				var diffstatSummary = diffstatElem.getElementsByClassName("diffstat-numbers")[1];
				diffstatSummary.innerText = numLinesChanged;
				diffstatSummary.addEventListener("mouseover", function() { expandDiffstatDetails(this); });
				diffstatSummary.addEventListener("mouseout",  function() { collapseDiffstatDetails(this); });

				var diffstatDetails = diffstatElem.getElementsByClassName("diffstat-numbers")[0];
				diffstatDetails.getElementsByClassName("added")[0].innerText   = "+" + numLinesAdded;
				diffstatDetails.getElementsByClassName("removed")[0].innerText = "-" + numLinesRemoved;

				var addedBar   = diffstatElem.getElementsByClassName("changes-bar")[0];
				var removedBar = diffstatElem.getElementsByClassName("changes-bar")[1];
				if (addedWidth   >= minWidth) addedBar.style.width   = addedWidth;
				else                           addedBar.style.visibility = "hidden";
				if (removedWidth >= minWidth) removedBar.style.width = removedWidth;
				else                           removedBar.style.visibility = "hidden";
			}
			filelist.appendChild(fileElem);
		}
		$("files").classList.remove("hidden");
	}

	// Auto-render diff unless it is very large
	if (commit.diff.length < 200000) {
		showDiff();
	} else {
		var diffEl = $("diff");
		diffEl.innerHTML = "<a class='showdiff' href=''>This is a large commit.<br>Click here or press 'v' to view.</a>";
		diffEl.getElementsByClassName("showdiff")[0].addEventListener("click", function(e) {
			e.preventDefault();
			commit.diffRendered = false; // allow re-render
			showDiff();
		});
	}
	hideNotification();
	enableFeatures();
};

// -----------------------------------------------------------------------
// Diffstat expand/collapse
// -----------------------------------------------------------------------
function expandDiffstatDetails(obj) {
	var children = obj.parentNode.childNodes;
	for (var i in children) {
		var c = children[i];
		if (c.classList && c.classList.contains("details"))
			c.classList.remove("hidden");
	}
}
function collapseDiffstatDetails(obj) {
	var children = obj.parentNode.childNodes;
	for (var i in children) {
		var c = children[i];
		if (c.classList && c.classList.contains("details"))
			c.classList.remove("hidden");
	}
}

// -----------------------------------------------------------------------
// DOMContentLoaded
// -----------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", function() {
	extractPrototypes();
	initResizeHandle();

	$("gist").addEventListener("click", function(e) {
		e.preventDefault();
		confirm_gist();
	});
});
