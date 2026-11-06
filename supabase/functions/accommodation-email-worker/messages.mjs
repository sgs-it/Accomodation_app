const TITLES = {
  admin_welcome: 'Welcome to Staff Accommodation',
  staff_created: 'New Staff Account Created',
  staff_deleted: 'Staff Account Deleted',
  room_shift_request: 'New Room Shift Request',
  leave_request: 'New Leave Request',
  room_shift_logged: 'Room Shift Logged',
  leave_started: 'Staff Marked On Leave',
  contract_expiry_reminder: 'Accommodation Contract Expiry Reminder',
};

export function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[c]);
}

export function renderEmail(event, recipient, config) {
  let subject = TITLES[event.kind];
  if (!subject) throw new Error('Unsupported email event');
  const url = new URL(config.site_url);
  if (url.protocol !== 'https:') throw new Error('Email login URL must use HTTPS');
  const data = event.payload ?? {};
  if (event.kind === 'contract_expiry_reminder') {
    if (![10, 5].includes(data.days_before)) throw new Error('Unsupported contract reminder threshold');
    subject = `Contract expires in ${data.days_before} days | ${data.location_name || 'Location'} | Room ${data.room_number || ''}`;
  }
  const lines = [];
  if (event.kind === 'admin_welcome') {
    lines.push(`Hello ${recipient.display_name || 'Administrator'},`,
      'Your administrator account has been created.',
      `Login email: ${recipient.email}`,
      'You will receive future accommodation alerts at this email address.',
      'Use the password provided separately by your company administrator.');
  } else if (event.kind === 'contract_expiry_reminder') {
    lines.push(`This accommodation contract expires in ${data.days_before} days.`,
      `Location: ${data.location_name || 'Not specified'}`,
      `Room: ${data.room_number || 'Not specified'}`,
      `Contract number: ${data.contract_number || 'Not specified'}`,
      `Expiry date: ${data.expiry_date}`,
      'Please review the contract and arrange renewal if required.');
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
