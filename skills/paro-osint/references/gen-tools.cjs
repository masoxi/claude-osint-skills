const {spawn}=require("child_process");
const W=new Set(["profile_disconnect","posts_create","posts_edit","posts_delete","engage_react","engage_comment","engage_share","connections_send","connections_accept","connections_reject","connections_withdraw","connections_remove","messaging_send","messaging_send-new","messaging_mark-read","companies_follow","companies_unfollow"]);
const OFF=new Set(["osint_classify","osint_names","osint_matrix","osint_stats","osint_scan"]);
const p=spawn("node",[process.argv[2]],{stdio:["pipe","pipe","ignore"]});
let buf="";
p.stdout.on("data",d=>{buf+=d;for(const l of buf.split("\n")){let m;try{m=JSON.parse(l)}catch{continue}
 if(m.id!==2)continue;
 const groups={};
 for(const t of m.result.tools){const g=t.name.split("_")[0];(groups[g]=groups[g]||[]).push(t)}
 const out=[];
 for(const [g,ts] of Object.entries(groups)){
  out.push(`\n## ${g}\n`);
  for(const t of ts){
   const tag=W.has(t.name)?" — **WRITE, confirm first**":OFF.has(t.name)?" — offline":"";
   out.push(`### \`${t.name}\`${tag}\n`);
   out.push((t.description||"").replace(/\s+/g," ").trim()+"\n");
   const props=t.inputSchema?.properties||{},req=t.inputSchema?.required||[];
   if(Object.keys(props).length){
    out.push("| param | type | req | notes |\n|---|---|---|---|");
    for(const [k,v] of Object.entries(props)){
     let ty=v.type||(v.anyOf?v.anyOf.map(x=>x.type).join("|"):"");
     if(v.enum)ty="enum: "+v.enum.join(", ");
     let notes=(v.description||"").replace(/\s+/g," ").replace(/\|/g,"\|");
     if(v.default!==undefined)notes+=` (default ${JSON.stringify(v.default)})`;
     if(v.maxLength)notes+=` (max ${v.maxLength} chars)`;
     if(v.maximum!==undefined)notes+=` (max ${v.maximum})`;
     out.push(`| \`${k}\` | ${ty} | ${req.includes(k)?"yes":""} | ${notes} |`);
    }
    out.push("");
   }
  }
 }
 console.log(out.join("\n"));p.kill();process.exit(0);
}});
const s=o=>p.stdin.write(JSON.stringify(o)+"\n");
s({jsonrpc:"2.0",id:1,method:"initialize",params:{protocolVersion:"2025-03-26",capabilities:{},clientInfo:{name:"x",version:"1"}}});
setTimeout(()=>{s({jsonrpc:"2.0",method:"notifications/initialized"});s({jsonrpc:"2.0",id:2,method:"tools/list"})},500);
setTimeout(()=>{p.kill();process.exit(1)},15000);
