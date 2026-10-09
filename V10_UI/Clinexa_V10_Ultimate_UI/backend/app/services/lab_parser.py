"""Conservative text parser. Confidence describes parsing, never clinical validity."""
import re
LINE=re.compile(r'^\s*(?P<test>[A-Za-z][A-Za-z0-9 ()/.,%-]{1,80}?)\s{2,}(?P<value>[<>]?\s*-?\d+(?:\.\d+)?|Positive|Negative|Reactive|Nonreactive)\s+(?P<unit>[A-Za-zµμ%][A-Za-z0-9µμ%/^.-]*)?(?:\s+(?P<range>[<>]?\s*\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?))?\s*$',re.I)
def parse_lab(text):
    fields=[];unparsed=[]
    for number,line in enumerate(text.splitlines(),1):
        if not line.strip(): continue
        match=LINE.match(line)
        if not match:
            unparsed.append({'line':number,'text':line});continue
        d=match.groupdict()
        fields.append({'line':number,'source':line,'test_name':d['test'].strip(),'result_value':d['value'].replace(' ',''),'unit':d['unit'] or '',
            'reference_range':d['range'] or '', 'confidence':{'test_name':.8,'result_value':.9,'unit':.75 if d['unit'] else 0,'reference_range':.7 if d['range'] else 0},'requires_verification':True})
    return {'fields':fields,'unparsed_lines':unparsed,'warning':'Review every field against the source before saving. No clinical interpretation is performed.'}
