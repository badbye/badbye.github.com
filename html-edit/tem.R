## 文件位置
path = '/home/yaleidu/R.data/2013-11-03-diliujie.html'

## 添加第一部分
doc = readLines(path)
ouput = 0

sep_1 = which(doc=='<style type="text/css">')[1]
if (sep_1 > 0){
  output = doc[1:sep_1] 
}
write(output, 'output')

## 添加表格CSS
file.append('output', '/home/yaleidu/bolg/badbye.github.com/html-edit/html-edit_css')

## 添加代码CSS
sep_2 = which(doc %in% c('pre {', 'pre {\t'))
sep_3 = which(doc =='<body>')
if (sep_2 > 0 & sep_3>0) {
  write(doc[sep_2:sep_3], 'output', append=T)
}

## 添加header
file.append('output', '/home/yaleidu/bolg/badbye.github.com/html-edit/html-edit_header')

## 关闭div标签
sep_4 = which(doc =='</body>')
write(doc[(sep_3+1):(sep_4-1)], 'output', append=T)
write(readLines('/home/yaleidu/bolg/badbye.github.com/html-edit/add_disqus',
                'output', append=T))
write("</div>\n</body></html>", 'output', append=T)






