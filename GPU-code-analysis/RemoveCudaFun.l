%option noyywrap nodefault yylineno
%x FUNCTION
%x KERNAL

%{
  //这个文件是要对第一遗留的文件进行第二次预处理，这个部分是要又Java文件生成的，所以我们需要规范的代码
  //这个程序首先将会被执行多次，首先要找到的是所有要删除的CUDA相关的变量、函数和所有相关的行号，变量和行号不再增加时我们就可以
  //把遗留了墓碑的代码输出出来，整个阶段执行完毕之后我们将要生成的就是一个完整的C语言文件，这个文件在加上一些头文件之后就可以直接运行
  //这个程序主要要记录下来三个东西的行号，第一个是核函数声明以及实现
  //第二个是CUDA函数，调用CUDA函数的行直接删除，如果这个函数左边有等号，那么左边的那个变量也要作为CUDA相关变量登记。
  //第三个就是CUDA相关的变量，首先我们需要找到就是和CUDA直接相关的变量，变量可能有这么几种可能，一个是在等号右边，一个是在函数里面，还有一个是在等号右边的函数里面
  //对于在函数形参里面我们首先就会在函数的时候删除，如果检测到函数左边也有等号，要就把左边的那个变量也作为要连坐的变量，但是这个变量要删除的只有这个行号之后的部分
  //所以说对于要删除的变量我们要记录两个值，一个是变量名，还有一个就是行号，这个行号记录了我们要删除哪一行之下所有变量直接相关代码。
  //每一次扫描我们要搞定返回两个东西，一个是下一次要扫描的函数以及变量，还有就是要删除的行号

  //我们要从外面要输入的扫描元素主要分为3个部分，第一个是核函数，然后就是CUDA相关变量，然后就是和CUDA变量相关函数
  //如果CUDA变量出现在一个函数体里面，那么还是删除这一行，如果一个关键变量出现在一个函数体里面，那我们要做好替换工作，此外这个函数
  //的调用中所有的形参会会作为关键词被勾选

  //----------------------------------------------------------------------------
  //还是打算使用一种更为激进的删除策略，首先是CUDA类型出现在函数形参的部分，这里直接删除函数的声明、实现和调用
  //然后就是CUDA类型的变量名出现在函数体中，那只删除函数体的这一行
  //如果CUDA类型的变量出现的if语句的条件中，那么就删除整个if和附带的所有else
  //如果CUDA类型的变量出现在while语句中那么就删除整个while的条件以及代码块，当然还有do，while语句，之前有do，那就把do和while之间的东西全部删掉
  //for（）括号中如果出现了CUDA类型的变量，那么就要直接去掉这个for这一行和整个for的语句块
  //但是为了flex的正常运行，我们先要删掉内核函数和cuda函数，然后删掉变量，这个文件所做的事情就是删掉CUDA内核函数和CUDA函数

  //----------------------------------------------------------------------------
  //上面说的是一整个二次处理的安排，此文件是二次处理的第一阶段，主要处理的是核函数和cuda库中的函数，当然这个文件在最后是要使用java外壳程序生成的
  //所以说关键函数、内核函数、和普通cuda函数要根据第一步的结果由java外壳程序添加。

  extern int yylineno;
  //这个变量判断出是不是在这一行中曾经过一个等号，初始化为0，在每一行分号处置为0。
  int equal;
  //这儿变量用来判断括号的嵌套等级
  int smallnesting;
  //这个变量记录了代码大括号的嵌套等级
  int nesting;
  //还有一个变量记录了上一个记录的“要求被删除的行的行号”
  int lastDeleteLine;
  //这个数组存储了所有要删除的行号
  int lineCount[10000];
  //这个变量存着数组的下一个空位的索引
  int lineCountIndex;
  //这个数组存着要输出关键变量的行号
  int outputIine[1000];
  //这个变量存着上一个数组的指向下一个空行的索引
  int outputIineIndex;
  //这个字符串数组存着所需要的所有的变量名
  char* varName[1000];
  //这个变量存着上一次数组的下一个空位的索引
  int varCountIndex;
  //这个函数用来向数组中添加一个行号
  void recordLineNumber(int yylineno);
%}

KERNALFUNCTION ("bitreverse")
CUDAFUNCTION  ("cudaGetErrorString"|"cudaThreadSynchronize"|"cudaGetLastError"|"cudaDeviceReset"|"cudaFree")
IMPORTANTFUNCTION ("cudaConfigureCall"|"cudaMemcpy"|"cudaMalloc")

%%
{IMPORTANTFUNCTION}(" "|\t|\n)*"("  {
  //这个函数的形参里面有我们想要的参数
  printf("%s",yytext);
  fprintf(yyout,"%d####%s####",yylineno,yytext);
  smallnesting = 1;
  BEGIN FUNCTION;
}

{KERNALFUNCTION} {
  printf("%s",yytext);
  //这个函数是用来处理所有的核函数的
  //这里要注意命名模式的使用
  //printf("找到了内核函数在第%d行\n",yylineno);
  recordLineNumber(yylineno);
  BEGIN KERNAL;
}

{CUDAFUNCTION}(" "|\n|\t)*"("  {
  //这里函数处理CUDA函数的调用，我们要删除这种调用，如果碰到我们想要的函数，我们要解决一个关键变量的记录和墓碑的问题
  //所有的关键关键变量之后再处理，这里先想办法去除关键变量并且留下墓碑
  printf("%s",yytext);
  recordLineNumber(yylineno);
}

<FUNCTION>"(" {
  printf("%s",yytext);
  fprintf(yyout,"%s",yytext);
  smallnesting++;
}

<FUNCTION>")" {
  printf("%s",yytext);
  smallnesting--;
  if(smallnesting == 0){
    //小括号的嵌套等级为0，那么就说明我们的整个函数的形参列表已经走完了
    fprintf(yyout,"\n");
    BEGIN INITIAL;
  }else{
    fprintf(yyout,"%s",yytext);
  }
}

<FUNCTION>.  {
  //这里我们试图去返回一整个形参列表
  printf("%s",yytext);
  fprintf(yyout , "%s" , yytext);
}


<FUNCTION>\n  {
  printf("%s",yytext);
}

"=" {
  //如果找到了等号，我们需要把等号之前的变量也找到
  printf("%s",yytext);
}



<KERNAL>^(.|\n)  {
  printf("%s",yytext);
  //为了提升效率记录行号的事情只在第一个字符的时候进行
  recordLineNumber(yylineno);
  //如果在一行的一开始就发现了大括号，也要适当修改嵌套等级这个值
  if(strcmp(yytext,"{")==0)
  {
    nesting++;
  }
  if(strcmp(yytext,"}")==0)
  {
    nesting--;
    if(nesting==0){
      BEGIN INITIAL;
    }
  }
}

<KERNAL>"{" {
  //printf("匹配到左括号nesting=%d\n",nesting);
  nesting++;
}

<KERNAL>"}" {
  //printf("匹配到右括号nesting=%d\n",nesting);
  nesting--;
  if(nesting==0){
    BEGIN INITIAL;
  }
}

<KERNAL>";" {
  printf("%s",yytext);
  if(nesting==0){
    BEGIN INITIAL;
  }
}

<KERNAL>.  {
  //在检测到内核函数之后的所有东西都会被忽略，除非发生下面几种情况：
  //首先我们需要一个变量来记录代码的嵌套等级，在遇到{的时候嵌套等级增加，在遇到}的时候嵌套等级下降
  //1、如果我们发现了一个分号，并且这个分号所在的位置嵌套等级为0，那么就说明函数名之后经过形参列表直接就是分号了，那么这个时候就要到此位置退出KERNAL状态
  //当然这一行的行号会被记录
  //2、如果碰到了一个左大括号，那么这个时候要适当修改nesting的值，如果碰到的是右大括号，那么在修改nesting的值之余如果发现了nesting的值已经退化到了0，
  //那么也要回到初始状态，中间所有经历的行号都要记录下来。
  printf("%s",yytext);

}

<KERNAL>\n  {
  printf("%s",yytext);
}


";" {
  equal = 0;
  printf("%s",yytext);
}

.|\n  {
  printf("%s",yytext);
}



%%
void recordLineNumber(int yylineno){
  if(yylineno > lastDeleteLine){
    lineCount[lineCountIndex] = yylineno;
    lineCountIndex++;
    /*for(int i = 0; i < lineCountIndex; i++){
      printf("%d,",lineCount[i]);
    }
    printf("\n");*/
    lastDeleteLine = yylineno;
  }
}

int main(int argc, char *argv[]){
  yylineno = 1;
  nesting = 0;
  lastDeleteLine = 0;
  lineCountIndex = 0;
  varCountIndex = 0;
  outputIineIndex = 0;
  /*首先把输入和输出文件规定好*/
  if(argc > 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
    if(!(yyout = fopen(argv[2],"w"))){
      //这里定义的输出文件将会返回重要函数的形参列表
      perror(argv[2]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");

  yylex();
  printf("\n");
  for(int i = 0; i < lineCountIndex; i++){
    printf("%d,",lineCount[i]);
  }
  printf("\n");
}
