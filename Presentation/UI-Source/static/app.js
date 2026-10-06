document.querySelectorAll('[data-autosubmit]').forEach(select=>select.addEventListener('change',()=>select.form.requestSubmit()));
document.querySelectorAll('form[data-confirm]').forEach(form=>form.addEventListener('submit',event=>{if(!confirm(form.dataset.confirm))event.preventDefault();}));
document.querySelectorAll('[data-print]').forEach(button=>button.addEventListener('click',()=>window.print()));
document.querySelectorAll('[data-back]').forEach(button=>button.addEventListener('click',()=>history.back()));
document.querySelectorAll('nav a').forEach(link=>{if(link.pathname===location.pathname)link.classList.add('active');});
