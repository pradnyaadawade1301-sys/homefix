package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// SupportInboxPage serves GET /support-inbox — a small self-contained web
// page where HomeFix support staff read customers' Live Chat messages and
// reply. It has no data of its own: staff sign in with an admin account
// (POST /api/v1/auth/login) and the page then calls the role-protected
// admin endpoints (GET /api/v1/admin/support/chats, .../:user_id/messages,
// POST .../:user_id/messages), so nothing here bypasses existing auth.
func SupportInboxPage(c *gin.Context) {
	c.Header("Cache-Control", "no-store")
	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(supportInboxHTML))
}

const supportInboxHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HomeFix Support Inbox</title>
<style>
  *{box-sizing:border-box}
  body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f3f6f9;color:#1b2430;height:100vh}
  #login{max-width:340px;margin:12vh auto;background:#fff;padding:28px;border-radius:14px;box-shadow:0 2px 12px rgba(0,0,0,.08)}
  #login h2{margin:0 0 16px}
  input[type=text],input[type=password],#reply{width:100%;padding:11px 12px;border:1px solid #cfd8e0;border-radius:10px;font-size:14px;margin-bottom:10px}
  button{background:#0e7569;color:#fff;border:0;border-radius:10px;padding:11px 18px;font-size:14px;cursor:pointer}
  button:disabled{opacity:.5}
  #err{color:#c0392b;font-size:13px;min-height:18px}
  #app{display:none;height:100vh;flex-direction:column}
  header{background:#0e7569;color:#fff;padding:12px 18px;display:flex;justify-content:space-between;align-items:center}
  header b{font-size:16px}
  header a{color:#fff;font-size:13px;cursor:pointer;text-decoration:underline}
  main{flex:1;display:flex;min-height:0}
  #list{width:320px;background:#fff;border-right:1px solid #e1e7ec;overflow-y:auto}
  .chat{padding:12px 14px;border-bottom:1px solid #eef2f5;cursor:pointer}
  .chat:hover,.chat.sel{background:#eaf5f3}
  .chat .top{display:flex;justify-content:space-between;font-size:14px}
  .chat .name{font-weight:600}
  .chat .time{color:#7b8794;font-size:11px}
  .chat .last{color:#5f6b76;font-size:13px;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .chat .tag{display:inline-block;font-size:10px;background:#fde8d4;color:#a4520c;border-radius:6px;padding:1px 6px;margin-left:6px}
  #pane{flex:1;display:flex;flex-direction:column;min-width:0}
  #thread{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:8px}
  .msg{max-width:70%;padding:9px 12px;border-radius:12px;font-size:14px;white-space:pre-wrap;word-wrap:break-word}
  .msg.user{background:#fff;align-self:flex-start;border:1px solid #e1e7ec}
  .msg.admin{background:#0e7569;color:#fff;align-self:flex-end}
  .msg .t{font-size:10px;opacity:.7;margin-top:4px}
  .msg img{max-width:220px;border-radius:8px;display:block;margin-bottom:4px}
  .msg video{max-width:260px;border-radius:8px;display:block;margin-bottom:4px}
  #composer{display:flex;gap:8px;padding:12px;background:#fff;border-top:1px solid #e1e7ec}
  #reply{margin:0;resize:none;height:44px}
  .empty{color:#8a96a3;text-align:center;margin:auto;font-size:14px}
  @media(max-width:700px){#list{width:130px}.chat .last{display:none}}
</style>
</head>
<body>
<div id="login">
  <h2>Support Inbox</h2>
  <input id="ident" type="text" placeholder="Admin email" autocomplete="username">
  <input id="pass" type="password" placeholder="Password" autocomplete="current-password">
  <div id="err"></div>
  <button id="loginBtn" style="width:100%">Sign in</button>
</div>
<div id="app">
  <header><b>HomeFix Support Inbox</b><a id="logout">Sign out</a></header>
  <main>
    <div id="list"><div class="empty" style="padding:20px">No chats yet</div></div>
    <div id="pane">
      <div id="thread"><div class="empty">Select a chat on the left</div></div>
      <div id="composer" style="display:none">
        <textarea id="reply" placeholder="Type your reply..."></textarea>
        <button id="send">Send</button>
      </div>
    </div>
  </main>
</div>
<script>
const API='/api/v1';
let token=sessionStorage.getItem('sup_token')||'';
let selected=null, chats=[], lastThreadKey='';
const $=id=>document.getElementById(id);

async function api(path,opts={}){
  const r=await fetch(API+path,Object.assign({headers:{'Content-Type':'application/json','Authorization':'Bearer '+token}},opts));
  const j=await r.json().catch(()=>({}));
  if(r.status===401){signOut();throw new Error('Session expired');}
  if(!r.ok||j.success===false)throw new Error(j.error||('Error '+r.status));
  return j.data;
}
function signOut(){sessionStorage.removeItem('sup_token');token='';location.reload();}
$('logout').onclick=signOut;

async function login(){
  $('err').textContent='';$('loginBtn').disabled=true;
  try{
    const r=await fetch(API+'/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({identifier:$('ident').value.trim(),password:$('pass').value})});
    const j=await r.json();
    if(!r.ok||j.success===false)throw new Error(j.error||'Login failed');
    token=j.data.access_token;
    await api('/admin/support/chats'); // 403 here means not an admin
    sessionStorage.setItem('sup_token',token);
    start();
  }catch(e){token='';$('err').textContent=e.message.includes('403')||/forbidden|role/i.test(e.message)?'This account is not an admin.':e.message;}
  $('loginBtn').disabled=false;
}
$('loginBtn').onclick=login;
$('pass').addEventListener('keydown',e=>{if(e.key==='Enter')login();});

function fmt(t){const d=new Date(t);return d.toLocaleString([], {day:'numeric',month:'short',hour:'numeric',minute:'2-digit'});}

async function loadChats(){
  try{
    chats=await api('/admin/support/chats')||[];
    const list=$('list');list.innerHTML='';
    if(!chats.length){list.innerHTML='<div class="empty" style="padding:20px">No chats yet</div>';return;}
    chats.forEach(c=>{
      const el=document.createElement('div');
      el.className='chat'+(c.user_id===selected?' sel':'');
      const top=document.createElement('div');top.className='top';
      const nm=document.createElement('span');nm.className='name';nm.textContent=c.user_name||'Customer';
      if(c.last_sender_role==='user'){const tg=document.createElement('span');tg.className='tag';tg.textContent='needs reply';nm.appendChild(tg);}
      const tm=document.createElement('span');tm.className='time';tm.textContent=fmt(c.last_message_at);
      top.appendChild(nm);top.appendChild(tm);
      const last=document.createElement('div');last.className='last';last.textContent=c.last_message||'[photo/video]';
      el.appendChild(top);el.appendChild(last);
      el.onclick=()=>{selected=c.user_id;lastThreadKey='';loadChats();loadThread(true);$('composer').style.display='flex';};
      list.appendChild(el);
    });
  }catch(e){}
}

async function loadThread(scroll){
  if(!selected)return;
  try{
    const msgs=await api('/admin/support/chats/'+selected+'/messages')||[];
    const key=msgs.length+':'+(msgs.length?msgs[msgs.length-1].id:'');
    if(key===lastThreadKey)return;
    lastThreadKey=key;
    const th=$('thread');const nearBottom=th.scrollHeight-th.scrollTop-th.clientHeight<80;
    th.innerHTML='';
    msgs.forEach(m=>{
      const el=document.createElement('div');el.className='msg '+(m.sender_role==='admin'?'admin':'user');
      if(m.attachment_url){
        if(m.attachment_type==='video'){const v=document.createElement('video');v.src=m.attachment_url;v.controls=true;el.appendChild(v);}
        else{const a=document.createElement('a');a.href=m.attachment_url;a.target='_blank';const i=document.createElement('img');i.src=m.attachment_url;a.appendChild(i);el.appendChild(a);}
      }
      if(m.message){const t=document.createElement('div');t.textContent=m.message;el.appendChild(t);}
      const tt=document.createElement('div');tt.className='t';tt.textContent=fmt(m.created_at);el.appendChild(tt);
      th.appendChild(el);
    });
    if(scroll||nearBottom)th.scrollTop=th.scrollHeight;
  }catch(e){}
}

async function send(){
  const text=$('reply').value.trim();
  if(!text||!selected)return;
  $('send').disabled=true;
  try{
    await api('/admin/support/chats/'+selected+'/messages',{method:'POST',body:JSON.stringify({message:text})});
    $('reply').value='';lastThreadKey='';
    await loadThread(true);loadChats();
  }catch(e){alert(e.message);}
  $('send').disabled=false;
}
$('send').onclick=send;
$('reply').addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();send();}});

function start(){
  $('login').style.display='none';$('app').style.display='flex';
  loadChats();
  setInterval(()=>{loadChats();loadThread(false);},3000);
}
if(token){api('/admin/support/chats').then(start).catch(()=>{token='';sessionStorage.removeItem('sup_token');});}
</script>
</body>
</html>`