const TITLES = {
  admin_welcome: 'Welcome to Staff Accommodation',
  staff_created: 'New Staff Account Created',
  staff_deleted: 'Staff Account Deleted',
  room_shift_request: 'New Room Shift Request',
  leave_request: 'New Leave Request',
  room_shift_logged: 'Room Shift Logged',
  leave_started: 'Staff Marked On Leave',
};

export function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[c]);
}

export function renderEmail(event, recipient, config) {
  const subject = TITLES[event.kind];
  if (!subject) throw new Error('Unsupported email event');
  const url = new URL(config.site_url);
  if (url.protocol !== 'https:') throw new Error('Email login URL must use HTTPS');
  const data = event.payload ?? {};
  const lines = [];
  if (event.kind === 'admin_welcome') {
    lines.push(`Hello ${recipient.display_name || 'Administrator'},`,
      'Your administrator account has been created.',
      `Login email: ${recipient.email}`,
      'You will receive future accommodation alerts at this email address.',
      'Use the password provided separately by your company administrator.');
  } else {
    const fields = [
      ['Staff name', data.staff_name], ['Staff ID', data.staff_id],
      ['Leave type', data.leave_type], ['Start date', data.from_date],
      ['End date', data.to_date], ['Shift date', data.shift_date],
      ['From bed', data.from_bed], ['To bed', data.to_bed], ['Reason', data.reason],
    ];
    for (const [label, value] of fields) {
      if (value != null && String(value).trim() !== '') lines.push(`${label}: ${value}`);
    }
    if (event.created_at) lines.push(`Event time (UTC): ${new Date(event.created_at).toISOString()}`);
    lines.push('Please review the details in the accommodation app.');
  }
  const text = `${subject}\n\n${lines.join('\n')}\n\nOpen app: ${url.href}`;
  return {
    subject,
    textContent: text,
    htmlContent: '<!doctype html><html><body style="font-family:Arial,sans-serif;color:#172033">' +
      `<h2>${escapeHtml(subject)}</h2><p>${lines.map(escapeHtml).join('<br>')}</p>` +
      `<p><a href="${escapeHtml(url.href)}">Open Staff Accommodation</a></p></body></html>`,
  };
}
