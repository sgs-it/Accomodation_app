import assert from "node:assert/strict";
import test from "node:test";
import { toPushText } from "./push_message.mjs";

for (const type of ["Leave", "Room Shift"]) {
  test(`${type} request removes bold tags and keeps paragraph breaks`, () => {
    const body = `Staff member <b>John Smith</b> has submitted a new ${type} request.<br/><br/>Please review it in the Admin Dashboard.`;
    assert.equal(toPushText(body),
      `Staff member John Smith has submitted a new ${type} request.\n\nPlease review it in the Admin Dashboard.`);
    // The original HTML remains available to the email payload.
    assert.ok(body.includes("<b>John Smith</b>"));
    assert.ok(body.includes("<br/><br/>"));
  });
}

test("already plain reminder messages keep their content", () => {
  const body = "Reminder: John Smith is returning in 3 days. Please assign a bed.";
  assert.equal(toPushText(body), body);
});

test("decodes common email entities in names and reasons", () => {
  assert.equal(toPushText("<b>O&#39;Brien &amp; Sons</b>&nbsp;&quot;Leave&quot;"),
    'O\'Brien & Sons "Leave"');
  assert.equal(toPushText("&#x1F3E0; &lt; 3 days"), "🏠 < 3 days");
});

test("supports alternate break tags and block elements", () => {
  assert.equal(toPushText("<p>First line</p><DIV>Second<BR />Third</DIV>"),
    "First line\nSecond\nThird");
});

test("preserves plain comparisons and unicode names", () => {
  assert.equal(toPushText("<b>José 李</b>: 2 < 3 and 5 > 4"), "José 李: 2 < 3 and 5 > 4");
});

test("omits non-visible HTML content and normalizes whitespace", () => {
  assert.equal(toPushText("<!-- comment --><style>b{color:red}</style><script>ignored()</script>  Staff\t name<br><br><br> Details "),
    "Staff name\n\nDetails");
});

test("handles empty, missing, and invalid entity input without throwing", () => {
  assert.equal(toPushText(""), "");
  assert.equal(toPushText(undefined), undefined);
  assert.equal(toPushText(null), null);
  assert.equal(toPushText("&#99999999;"), "&#99999999;");
});
