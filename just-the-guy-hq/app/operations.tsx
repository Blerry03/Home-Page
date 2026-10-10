'use client';
import {useCallback,useEffect,useMemo,useState} from 'react';
import {createClient} from '@supabase/supabase-js';
import {Plus,Trash2,Package,Clock3,CheckCircle2} from 'lucide-react';
import type {Job,Client} from '../lib/data';

type Material={id:string;organization_id:string;job_id:string|null;item_name:string;quantity:number;unit:string;state:'needed'|'ordered'|'received';notes:string|null};
type TimeEntry={id:string;organization_id:string;job_id:string|null;employee_name:string;work_date:string;hours:number;notes:string|null};
type Kind='materials'|'hours';
const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const api=url&&key?createClient(url,key):null;
const demoKey='jtg-operations-v05';
const today=()=>{const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`};
const fresh=()=>({materials:[] as Material[],hours:[] as TimeEntry[]});
export default function Operations({kind,organizationId,jobs,clients,compact=false,onOpen}:{kind:Kind;organizationId:string;jobs:Job[];clients:Client[];compact?:boolean;onOpen?:()=>void}){
 const [materials,setMaterials]=useState<Material[]>([]);
 const [hours,setHours]=useState<TimeEntry[]>([]);
 const [loading,setLoading]=useState(true);
 const [error,setError]=useState('');
 const [saving,setSaving]=useState(false);
 const [item,setItem]=useState('');const [quantity,setQuantity]=useState('1');const [unit,setUnit]=useState('each');const [state,setState]=useState<Material['state']>('needed');
 const [employee,setEmployee]=useState('');const [workDate,setWorkDate]=useState(today);const [worked,setWorked]=useState('');
 const [jobId,setJobId]=useState('');const [notes,setNotes]=useState('');
 const fetchData=useCallback(async()=>{
   if(!api){try{const v=JSON.parse(localStorage.getItem(demoKey)||'{}');setMaterials(v.materials||[]);setHours(v.hours||[])}catch{setError('Unable to read local demo data.')}setLoading(false);return;}
   const [m,h]=await Promise.all([api.from('material_items').select('*').eq('organization_id',organizationId).order('created_at',{ascending:false}),api.from('time_entries').select('*').eq('organization_id',organizationId).order('work_date',{ascending:false})]);
   if(m.error||h.error){setError((m.error||h.error)?.message||'Unable to read records. Did you run upgrade-v0.5.sql?');}else{setMaterials(m.data as Material[]);setHours(h.data as TimeEntry[]);setError('');}setLoading(false);
 },[organizationId]);
 useEffect(()=>{void fetchData()},[fetchData]);
 const jobLabel=(id:string|null)=>{const j=jobs.find(x=>x.id===id);return j?`${clients.find(c=>c.id===j.client_id)?.name||'Customer'} · ${j.title}`:'General / no job'};
 const outstanding=useMemo(()=>materials.filter(m=>m.state!=='received'),[materials]);
 const thisWeek=useMemo(()=>{const d=new Date();const day=(d.getDay()+6)%7;d.setDate(d.getDate()-day);d.setHours(0,0,0,0);return hours.filter(h=>new Date(h.work_date+'T12:00:00')>=d).reduce((s,h)=>s+Number(h.hours),0)},[hours]);
 const demoUpdate=(patch:{materials?:Material[];hours?:TimeEntry[]})=>{const next={materials, hours,...patch};localStorage.setItem(demoKey,JSON.stringify(next));setMaterials(next.materials);setHours(next.hours)};
 async function add(e:React.FormEvent){e.preventDefault();setError('');setSaving(true);
  try{
    if(kind==='materials'){
     const n=Number(quantity);if(!item.trim()||!Number.isFinite(n)||n<=0)throw Error('Enter a material and quantity greater than zero.');
     const row={organization_id:organizationId,job_id:jobId||null,item_name:item.trim(),quantity:n,unit:unit.trim()||'each',state,notes:notes.trim()||null};
     if(api){const {error}=await api.from('material_items').insert(row);if(error)throw error;await fetchData()}else demoUpdate({materials:[{...row,id:crypto.randomUUID()},...materials]});setItem('');setQuantity('1');setState('needed');
    }else{
     const n=Number(worked);if(!employee.trim()||!workDate||!Number.isFinite(n)||n<=0||n>24)throw Error('Enter an employee, date and hours between 0 and 24.');
     const row={organization_id:organizationId,job_id:jobId||null,employee_name:employee.trim(),work_date:workDate,hours:n,notes:notes.trim()||null};
     if(api){const {error}=await api.from('time_entries').insert(row);if(error)throw error;await fetchData()}else demoUpdate({hours:[{...row,id:crypto.randomUUID()},...hours]});setWorked('');
    }setNotes('');
  }catch(e){setError(e instanceof Error?e.message:'Could not save.')}finally{setSaving(false)}
 }
 async function remove(id:string){if(!confirm('Delete this record?'))return;setError('');if(api){const {error}=await api.from(kind==='materials'?'material_items':'time_entries').delete().eq('id',id).eq('organization_id',organizationId);if(error){setError(error.message);return;}await fetchData()}else if(kind==='materials')demoUpdate({materials:materials.filter(x=>x.id!==id)});else demoUpdate({hours:hours.filter(x=>x.id!==id)});}
 async function changeState(m:Material,s:Material['state']){setError('');if(api){const {error}=await api.from('material_items').update({state:s}).eq('id',m.id).eq('organization_id',organizationId);if(error){setError(error.message);return;}await fetchData()}else demoUpdate({materials:materials.map(x=>x.id===m.id?{...x,state:s}:x)});}
 if(compact)return <div className="panel"><div className="panelHead"><h3>{kind==='materials'?'Materials to order':'Employee hours'}</h3>{kind==='materials'?<Package size={19}/>:<Clock3 size={19}/>}</div><div className="operationsPreview"><strong>{loading?'…':kind==='materials'?`${outstanding.length} outstanding item${outstanding.length===1?'':'s'}`:`${thisWeek.toFixed(2)} hours this week`}</strong><p>{kind==='materials'?'Needed or ordered materials across your jobs.':'Hours recorded this week across employees and jobs.'}</p><button className="outline" onClick={onOpen}>Open {kind==='materials'?'materials':'time tracking'}</button>{error&&<small className="error">{error}</small>}</div></div>;
 return <section className="panel operationsPanel"><div className="panelHead"><div><h3>{kind==='materials'?'Material orders':'Employee time entries'}</h3><p className="muted">{kind==='materials'?'Track needed, ordered, and received materials by job.':'Record hours worked by employee and job. Manual entries—not a payroll system.'}</p></div></div>{error&&<div className="error">{error}</div>}
 <form className="operationsForm" onSubmit={add}>
 {kind==='materials'?<><label>Material / item *<input required value={item} onChange={e=>setItem(e.target.value)} placeholder="6-inch gutter coil / A elbows"/></label><label>Quantity *<input required type="number" step="0.01" min="0.01" value={quantity} onChange={e=>setQuantity(e.target.value)}/></label><label>Unit<input value={unit} onChange={e=>setUnit(e.target.value)} placeholder="ft, each, roll"/></label><label>Status<select value={state} onChange={e=>setState(e.target.value as Material['state'])}><option value="needed">Needed</option><option value="ordered">Ordered</option><option value="received">Received</option></select></label></>:<><label>Employee name *<input required value={employee} onChange={e=>setEmployee(e.target.value)} placeholder="Employee's name"/></label><label>Work date *<input type="date" required value={workDate} onChange={e=>setWorkDate(e.target.value)}/></label><label>Hours *<input type="number" required min="0.01" max="24" step="0.01" value={worked} onChange={e=>setWorked(e.target.value)} placeholder="7.50"/></label></>}
 <label>Related job<select value={jobId} onChange={e=>setJobId(e.target.value)}><option value="">General / no job</option>{jobs.map(j=><option key={j.id} value={j.id}>{jobLabel(j.id)}</option>)}</select></label><label className="operationsNotes">Notes<input value={notes} onChange={e=>setNotes(e.target.value)} placeholder="Optional notes"/></label><button className="primary" type="submit" disabled={saving}><Plus size={16}/>{saving?'Saving…':'Add record'}</button></form>
 <div className="operationsResults"><strong>{kind==='materials'?`${outstanding.length} outstanding · ${materials.length} total material items`:`${thisWeek.toFixed(2)} hours this week · ${hours.length} entries`}</strong></div>
 {loading?<div className="comingSoon">Loading…</div>:kind==='materials'?materials.length?materials.map(m=><div className="operationsRow" key={m.id}><div className="rowMain"><strong>{m.item_name}</strong><small>{Number(m.quantity).toLocaleString()} {m.unit} · {jobLabel(m.job_id)}</small>{m.notes&&<small>{m.notes}</small>}</div><select aria-label={`Status for ${m.item_name}`} value={m.state} onChange={e=>void changeState(m,e.target.value as Material['state'])}><option value="needed">Needed</option><option value="ordered">Ordered</option><option value="received">Received</option></select><button className="iconBtn" aria-label={`Delete ${m.item_name}`} onClick={()=>void remove(m.id)}><Trash2 size={16}/></button></div>):<div className="comingSoon">No materials added yet.</div>:hours.length?hours.map(h=><div className="operationsRow" key={h.id}><div className="rowMain"><strong>{h.employee_name} · {Number(h.hours).toFixed(2)} hr</strong><small>{h.work_date} · {jobLabel(h.job_id)}</small>{h.notes&&<small>{h.notes}</small>}</div><button className="iconBtn" aria-label={`Delete hours for ${h.employee_name}`} onClick={()=>void remove(h.id)}><Trash2 size={16}/></button></div>):<div className="comingSoon"><CheckCircle2 size={18}/> No employee hours recorded yet.</div>}
 </section>
}
