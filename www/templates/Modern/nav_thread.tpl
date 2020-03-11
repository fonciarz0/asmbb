[css:navigation.css]
[css:posts.css]
[css:markdown.css]

[case:[special:lang]|
  [equ:btnNewPost=Answer]
  [equ:ttlEditThread=Edit the thread attributes.]
|
  [equ:btnNewPost=Отговор]
  [equ:ttlEditThread=Редактиране на атрибутите на темата.]
|
  [equ:btnNewPost=Ответить]
  [equ:ttlEditThread=Редакция атрибутов темы]
|
  [equ:btnNewPost=Répondre]
  [equ:ttlEditThread=Éditer le titre du sujet et les mots-clés.]
|
  [equ:btnNewPost=Antworten]
  [equ:ttlEditThread=Themenoptionen ändern.]
]

<div class="ui">
  [case:[special:canpost]| |<a class="btn" href="!post">[const:btnNewPost]</a>]
</div>
<h1 class="thread_caption">
[caption]
<div class="spacer"></div>
[case:[special:canedit]||<a href="!edit_thread" title="[const:ttlEditThread]"><svg version="1.1" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">
  <title>[const:ttlEditThread]</title>
  <path d="m19.2 6.7c-.835-.84-2.2-.84-3.02 0l-.755.76-10.6 10.6.00273.0027-.334.335s-1.06 1.07-3.45
           8.85l-.125.19c-.0436.19-.0854.381-.129.381-.0398.19-.0778.381-.118.381l-.0987.381c-.0761.255-.153.514-.231.782-.173.588-.594
           1.92-.117 2.4.459.461 1.79.0556 2.37-.118.264-.0788.522-.156.774-.232.116-.0352.23-.0697.343-.105.122-.0373.245-.0744.362-.111.151-.0464.3-.0921.444-.138.0435-.0135.0861-.027.129-.0404
           7.38-2.3 8.71-3.39 8.8-3.48.000833-.000594.000833-.000594.0014-.0012.0046-.0044.0078-.0072.0078-.0072l.342-.345.023.023
           10.6-10.6-.000118-.000119.755-.76c.835-.84.835-2.21 0-3.03l-6.05-6.07zm-6.87
           19.4c-.0093.0063-.0218.0145-.0351.023-.0073.0047-.0162.0103-.025.0158-.0089.0055-.0186.0116-.0288.0179-.0091.0055-.0186.0112-.0288.0175-.353.211-1.39.758-3.89
           1.67-.292.106-.611.219-.947.335l-3.57-3.58c.116-.339.23-.661.336-.956.907-2.51 1.45-3.58
           1.66-3.92.0051-.0084.00973-.0162.0143-.0238.00734-.0122.0142-.0234.0207-.0339.0051-.0082.0104-.0168.0149-.0238.00842-.0131.0166-.0259.023-.0352l.262-.263 6.47
           6.49-.268.268zm19-19.4-6.05-6.07c-.835-.84-2.2-.84-3.02 0l-1.42 1.51c-.835.84-.835 2.21 0 3.03l6.05 6.07c.835.84 2.2.84 3.02 0l1.51-1.52c.835-.84.835-2.21 0-3.03z"
        style="clip-rule:evenodd;fill-rule:evenodd"
  />
</svg></a>]
</h1>
<ul class="thread_tags">[special:threadtags=[id]]</ul>
