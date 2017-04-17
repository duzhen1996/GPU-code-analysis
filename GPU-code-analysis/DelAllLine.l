%option noyywrap nodefault yylineno
%x IF
%x WHILE
%x FOR
%{
  //这个文件中我们将执行真正意义上的删除操作，在这个删除操作中我们将要充分搞定if、while、for的所有情况
  extern int yylineno;
  //这个变量我们将会来判断是不是在while之前曾出现一个do
  int ifDO;

  //这里我们必须想到一个方法来解决dowhile嵌套的问题。我们尽量去解决10层以内的dowhile嵌套。
  //我们首先要把每次匹配到的DO都要记录一下这个DO的nesting值，然后我们在每次看到右大括号的时候
  //看看这个右大括号是不是可以满足是不是和最近的do的优先级一样，这样子就可以解决在do中嵌套while情况
  //我们使用ifDO作为这个数组的索引，这个变量存的是当前do的索引
  int DOnesting[10] = {};

  //ifDel是为了给else使用的，如果一个else之前的if被删除了，那么我们就需要把这个变量置为1。
  //所以说当我们匹配到一个要删除的if的时候这个
  int ifDel;

  //我们这里需要的是记录当我们要删除一个if或者while块的时候我们要记录的当前的nesting
  int nesting;
  int lastNesting;

  //这个东西本质上是要由java程序产生的，为了减少开销，我们需要生成一个从小到大排序的数组
  //现在这个程序也是由bug，就是在32行之后就不输出了。这行有一个printf输出，但是程序在这个位置就终止了。
  int lineCount[] = {3,4,5,6,7,8,16,21,23,27,28,36,38,46,50,51,62,64,65,66,72,73,74,80,81,82,93,94,95,101,102,103,110,111,112,114,115};
  //这个变量也是由java程序产生，是这个数组的大小
  int lineCountSize = 37;
  //因为行数只可能越来越大，所以我们很有必要记录下来最后一个匹配上的索引，下一次要匹配的时候我们从这个索引开始
  int lastindex;


  //这里我们还需要一组数组，这组数组的主要工作就是把我们需要的值在对应行添加上prinf语句
  //我们需要显示我们需要打印哪一个形参，这个形参可能是一个算式。这个时候还没有关键变量
  //而是关键形参的表达式，所以这里我们还需要一个数组，这个数组存的就是我们在对应行需要的关键形参
  //这些行因为有CUDA函数，所以一定在我们要删除的行中出现，所以当我们找到一行需要删除的时候我们需要
  //再扫描这个数组，看看只应该完全删除还是拿一个printf语句替换
  int printLinep[] = {21,36,62,62,80};
  char* keyParamEx[]={"sizeof(int) * WORK_SIZE","sizeof(int) * WORK_SIZE","1","WORK_SIZE","sizeof(int) * WORK_SIZE"};
  //这个变量是以上两个数组的大小
  int printLineSize = 5;
  //为了减少扫描的开销我们还是使用一个变量来记录我们扫描的最后一个索引，当我们扫描到的时候我们需要把扫描的当前索引赋给这个索引值
  //此外因为这个索引是重复的，索引当我们扫描到的时候不能立即停止，而是需要再往下扫描，知道数组中的行号大于当前行号
  int lastPindex;



  //这里的smallnesting和之前的不太一样，这里的只为for循环服务，这个时候这个东西只会为了保证可以定位到for的形参中
  int smallnesting;

  //这里我们建立一个缓冲区用来缓存do和while之间的所有东西
  //这儿缓冲区不是一个单纯的缓冲区，而是一个缓冲区数组
  //这个数组的大小和可以允许的do while嵌套层级是一样的
  char buffer[10][5000]={"","","","","","","","","",""};

  //这里我们需要建立一个缓冲区来缓存for循环中初始化、条件、和自增那部分的内容
  char bufferFor[1000] = "";

%}
%%
[^A-Za-z0-9]{1}"if"(" "|\t|\n)*"(" {
  printf("这里匹配到了if\n");
  //如果匹配到了if，我们就需要看看这一行是不是需要删除的
  for(int i = lastindex ; i < lineCountSize ; i++){
    if(yylineno == lineCount[i]){
      //如果if语句的这一行是需要删除的，那么我们就需要进入if模式，把当前的nesting记录下来，然后一直删到一个右花括号进行减
      //操作之后nesting保持一致
      //我们匹配到一个if之后如果发现这个if是需要删除的东西，那我们就需要中断这个循环并且把ifDel设为1，如果我们最后发现这行不是要删除的
      //那么我们就需要把ifDel置为0
      ifDel = 1;
      lastNesting = nesting;
      lastindex = i;

      //我们进行一下扫描，看看这一行是不是需要留下printf打印关键变量
      for(int j = lastPindex; j < printLineSize ; j++){
        if(yylineno == printLinep[j]){
          //这一行需要打印点东西，当然，打印的这点东西很可能是该放到DO缓冲区里面去的
          if(ifDO >= 0){
            //这里需要把打印的东西放到DO缓冲区中
            char tempbuffer[100] = "";
            snprintf(tempbuffer , 100 , "printf(\"%s is %%ld;\\n\",%s);", keyParamEx[j],keyParamEx[j] );
            strcat(buffer[ifDO],tempbuffer);
          }
          if(ifDO < 0){
            fprintf(yyout, "printf(\"%s is %%ld;\\n\",%s);", keyParamEx[j],keyParamEx[j]);

          }
          lastPindex = j;
          lastPindex++;
        }
        if(yylineno < printLinep[j]){
          //这里说明应该搜不到了
          break;
        }
      }

      BEGIN IF;
      break;
    }
    if(yylineno < lineCount[i]){
      //这里说明这个if是可以保留的
      ifDel = 0;
      if(ifDO >= 0){
        strcat(buffer[ifDO] , yytext);
      }else{
        ECHO;
      }
      break;
    }
  }
}

[^A-Za-z0-9]{1}"else"(" "|\n|\t)+  {
  //这种情况就是匹配到了else
  //为了准确匹配到else，我们需要在所有的右大括号后面加上回车
  printf("这里匹配到了else,ifDel = %d\n",ifDel);
  if(ifDel==1){
    //这个时候说明if状态还没有结束我们要延续if状态，一直删到下一个nesting自减之后相同嵌套等级的右括号
    BEGIN IF;
  }
  if(ifDel==0){
    //这里说明这个else是非常安全的else
    if(ifDO >= 0){
      strcat(buffer[ifDO] , yytext);
    }else{
      ECHO;
    }
  }
}

[^A-Za-z0-9]{1}"do"(" "|\n|\t)*"{" {
  //以现有的方法，我们还没有办法支持do while嵌套的问题，如果一个dowhile有其他的循环嵌套这会导致不可想象的问题
  //这里匹配到了do
  printf("我们匹配到了do\n");
  //如果我们匹配到了do就要搞定
  ifDO++;
  DOnesting[ifDO] = nesting;
  nesting++;
  //面对这种情况我们需要建立一个缓冲区，把do到while之间的东西先缓存下来，然后等到while的时候在判断是丢掉还是保留这个缓冲区
  //当我们碰到while之后我们把ifDo重新置为0就好
  //这个时候我们需要重置缓冲区
  strcpy(buffer[ifDO],"");
  strcat(buffer[ifDO],yytext);
}

[^A-Za-z0-9]{1}"while"(" "|\n|\t)*"(" {

  //这里匹配到了while，首先我们需要注意这个位置是dowhile还是单纯的while
  //我们还是在一个循环中判断这一行是不是需要删除的。
  printf("我们匹配到了while，ifDO = %d\n,%s",ifDO,yytext);
  for(int i = lastindex ; i < lineCountSize ; i++){
    if(yylineno == lineCount[i]){
      printf("这个while需要被删除\n");
      //到了这里就说明这一行不管怎么样都是保不住了，我们看看没有要打印的东西
      for(int j = lastPindex; j < printLineSize ; j++){
        if(yylineno == printLinep[j]){

          fprintf(yyout, "printf(\"%s is %%ld;\\n\",%s);", keyParamEx[j],keyParamEx[j]);
          lastPindex = j;
          lastPindex++;
        }
        if(yylineno < printLinep[j]){
          //这里说明应该搜不到了
          break;
        }
      }

      //如果这个时候发现这个while是需要删除的，那么我们就进入while模式，这个模式的特点在于这个模式可能是后面直接接一个大括号
      //或者这个模式后面直接接的就是一个分号，说明前面接的是一个do
      if(ifDO >= 0 && (nesting == DOnesting[ifDO])){
        //这里说明这个while的后面接的是一个分号，前面有Do，这个时候我们需要单独处理，我们将缓冲区中的内容遗弃。
        ifDO--;
        lastindex = i;
        //在while状态中我们删除所有的分号之前的东西，当然我们还会保留换行符
        BEGIN WHILE;
        break;
      }else {
        //这里说明这个while前面是没有匹配的do的，在这个while之前没有do
        //那么这个时候我们我们的处理逻辑就和IF模式一样，一直删，删到嵌套等级一样的右大括号那里。
        lastNesting = nesting;
        lastindex = i;
        BEGIN IF;
        break;
      }
    }
    if(yylineno < lineCount[i]){
      //这里说明while是不用删除的，那么这里就要应对两种情况，一种是有do的情况，一种是没有do的情况
      printf("这个while不用删除ifDO=%d,nesting=%d,DOnesting=%d\n",ifDO,nesting,DOnesting[ifDO]);
      if(ifDO >= 0 && (nesting == DOnesting[ifDO])){
        //如果这个时候while之前有do，那么我们就要考虑把之前缓冲区之前的东西读进来了
        //这里说明栈顶的DO缓冲区的东西已经可以移到低一层的DO缓冲区
        printf("这个while之前有do\n");
        if(ifDO > 0){
          strcat(buffer[ifDO - 1],buffer[ifDO]);
          strcat(buffer[ifDO - 1],yytext);
        }

        if(ifDO == 0){
          printf("没有do while嵌套\n");
          fprintf(yyout, "%s",buffer[ifDO]);
          ECHO;
        }

        //当缓冲区用完的时候我们把这个缓冲区清空吧
        strcpy(buffer[ifDO],"");
        //把缓冲区之前的内容读进来之后我们还要把这个while读进去，整个文件的最后一个模式会负责这一行剩下的内容的读入
        ifDO--;
      }else if(ifDO >= 0){
        //如果这个while之前没有do，并且这个while没有什么不正常的地方，如果这个while在do语句块内，那么就会进入这个函数块
        //将当前匹配到的东西放到当前缓冲区
        strcat(buffer[ifDO],yytext);
        //剩下的部分会由整个文件最后的一个模式读入
      }else{
        ECHO;
      }
      break;
    }
  }
}

[^A-Za-z0-9]{1}"for"(" "|\n|\t)*/"(" {
  //这里我们需要一套逻辑来处理所有for循环的情况
  //我们需要在这里直接进入for模式
  //我们需要在for语句形参所在的这几行中看看有没有我们需要删除的行，如果有那我们就要删除
  //整个for，如果没有，就回到INITIAL模式就好了，我们在这里又需要一个缓冲区了，这个缓冲区需要
  //记录在for状态下的所有字符，如果在for语句的形参中我们发现了需要删除的行，那我们就删除整个缓冲区，并且把整个
  //状态进入IF状态，之后的处理和IF是相同的，就是把整个for代码块中的内容全部删除。
  printf("找到了for\n");
  smallnesting = 0;
  strcpy(bufferFor , "");
  strcat(bufferFor , yytext);
  BEGIN FOR;
}

<FOR>"("  {
  printf("我们匹配到了for前括号\n");
  smallnesting++;
  strcat(bufferFor,yytext);
}

<FOR>")"  {
  smallnesting--;
  printf("我们检测到for的后括号\n");
  strcat(bufferFor,yytext);
  if(smallnesting == 0) {

    //如果可以到达这里，这就说明这个for循环是不用全删的
    //我们按照要求，将缓冲区中的东西输出或者移动到do缓冲区
    if(ifDO>=0 ){
      strcat(buffer[ifDO],bufferFor);
    }
    if(ifDO < 0){
      fprintf(yyout, "%s",bufferFor);
      strcpy(bufferFor , "");
    }
    BEGIN INITIAL;
  }
}

<FOR>.|\n {
  for(int i = lastindex ; i < lineCountSize ; i++){
    if(yylineno == lineCount[i]){
      lastindex = i;

      //虽然不认为for循环的条件中，会有要保留的东西但是还是加上以防万一
      for(int j = lastPindex; j < printLineSize ; j++){
        if(yylineno == printLinep[j]){
          //这一行需要打印点东西，当然，打印的这点东西很可能是该放到DO缓冲区里面去的
          if(ifDO >= 0){
            //这里需要把打印的东西放到DO缓冲区中
            char tempbuffer[100] = "";
            snprintf(tempbuffer , 100 , "printf(\"%s is %%ld;\\n\",%s);", keyParamEx[j],keyParamEx[j] );
            strcat(buffer[ifDO],tempbuffer);
          }
          if(ifDO < 0){
            fprintf(yyout, "printf(\"%s is %%ld;\\n\",%s);", keyParamEx[j],keyParamEx[j]);
          }
          lastPindex = j;
          lastPindex++;
        }
        if(yylineno < printLinep[j]){
          //这里说明应该搜不到了
          break;
        }
      }
      lastNesting = nesting;
      BEGIN IF;
      break;
    }
    if(yylineno < lineCount[i]){
      //这里说明在for中的某一行并不是我们需要删除的，这个时候我们要做的就是把这里的东西放到for的缓冲区中
      strcat(bufferFor , yytext);
      break;
    }
  }
}

<WHILE>";"  {
  //这里是while之后的分号，我们需要在这里退回到INITIAL模式
  BEGIN INITIAL;
}

<WHILE>.  {
  //while状态有一部分和IF是重叠的，我们现在使用while是为了处理一种特殊的情况，首先就是dowhile的while之后的东西
  //我们需要去掉分号之前的东西
}

<WHILE>\n {
  ECHO;
}


<IF>"{" {
  nesting++;
}

<IF>\n  {
  //为了使我们的行号在每一次扫描的时候都可以统一，我们保持了每一次换行
  ECHO;
}

<IF>"}" {
  nesting--;
  if(nesting == lastNesting){
    printf("在第%d行回到INITIAL状态\n",yylineno);
    BEGIN INITIAL;
  }
}

<IF>. {
  //这里说明我们要删除了
}

"{" {
  nesting++;
  //如果这行是在do中的，那么我们就暂时把这个东西放到缓冲区
  printf("现在正在第%d行,nesting = %d\n",yylineno,nesting);
  for(int i = lastindex ; i < lineCountSize ; i++){
    if(yylineno == lineCount[i]){
      //如果这一行是要删除的，那我们就不管了
      lastindex = i;

      //看看要删除的这一行有没有关键变量
      for(int j = lastPindex; j < printLineSize ; j++){
        if(yylineno == printLinep[j]){
          //这一行需要打印点东西，当然，打印的这点东西很可能是该放到DO缓冲区里面去的
          if(ifDO >= 0){
            //这里需要把打印的东西放到DO缓冲区中
            char tempbuffer[100] = "";
            snprintf(tempbuffer , 100 , "printf(\"%s is %%d;\\n\",%s);", keyParamEx[j],keyParamEx[j] );
            strcat(buffer[ifDO],tempbuffer);
          }
          if(ifDO < 0){
            fprintf(yyout, "printf(\"%s is %%d;\\n\",%s);", keyParamEx[j],keyParamEx[j]);
          }
          lastPindex = j;
          lastPindex++;
        }
        if(yylineno < printLinep[j]){
          //这里说明应该搜不到了
          break;
        }
      }

      break;
    }
    if(yylineno < lineCount[i]){
      //如果这行是在do中的，那么我们就暂时把这个东西放到缓冲区
      if(ifDO >= 0){
        strcat(buffer[ifDO] , yytext);
      }else{
        ECHO;
      }
      break;
    }
  }
}

"}" {
  nesting--;
  printf("现在正在第%d行,nesting = %d\n",yylineno,nesting);
  for(int i = lastindex ; i < lineCountSize ; i++){
    if(yylineno == lineCount[i]){
      //如果这一行是要删除的，那我们就不管了
      lastindex = i;

      //看看要删除的这一行有没有关键变量
      for(int j = lastPindex; j < printLineSize ; j++){
        if(yylineno == printLinep[j]){
          //这一行需要打印点东西，当然，打印的这点东西很可能是该放到DO缓冲区里面去的
          if(ifDO >= 0){
            //这里需要把打印的东西放到DO缓冲区中
            char tempbuffer[100] = "";
            snprintf(tempbuffer , 100 , "printf(\"%s is %%d;\\n\",%s);", keyParamEx[j],keyParamEx[j] );
            strcat(buffer[ifDO],tempbuffer);
          }
          if(ifDO < 0){
            fprintf(yyout, "printf(\"%s is %%d;\\n\",%s);", keyParamEx[j],keyParamEx[j]);

          }
          lastPindex = j;
          lastPindex++;
        }
        if(yylineno < printLinep[j]){
          //这里说明应该搜不到了
          break;
        }
      }

      break;
    }
    if(yylineno < lineCount[i]){
      //如果这行是在do中的，那么我们就暂时把这个东西放到缓冲区
      if(ifDO >= 0){
        strcat(buffer[ifDO] , yytext);
      }else{
        ECHO;
      }
      break;
    }
  }
}

\n  {
  //如果这行是在do中的，那么我们就暂时把这个东西放到缓冲区
  if(ifDO >= 0){
    strcat(buffer[ifDO] , yytext);
  }else{
    ECHO;
  }
}

.  {
  //在这里我们将匹配到一行
  printf("现在正在第%d行\n",yylineno);

  //我们要在这一行里面看看有没有右大括号这种东西

  for(int i = lastindex ; i < lineCountSize ; i++){
    if(yylineno == lineCount[i]){
      //如果这一行是要删除的，那我们就不管了
      lastindex = i;

      //看看要删除的这一行有没有关键变量
      for(int j = lastPindex; j < printLineSize ; j++){
        if(yylineno == printLinep[j]){
          //这一行需要打印点东西，当然，打印的这点东西很可能是该放到DO缓冲区里面去的
          if(ifDO >= 0){
            //这里需要把打印的东西放到DO缓冲区中
            char tempbuffer[100] = "";
            snprintf(tempbuffer , 100 , "printf(\"%s is %%d;\\n\",%s);", keyParamEx[j],keyParamEx[j] );
            strcat(buffer[ifDO],tempbuffer);
          }
          if(ifDO < 0){
            fprintf(yyout, "printf(\"%s is %%d;\\n\",%s);", keyParamEx[j],keyParamEx[j]);

          }
          lastPindex = j;
          lastPindex++;
        }
        if(yylineno < printLinep[j]){
          //这里说明应该搜不到了
          break;
        }
      }

      break;
    }
    if(yylineno < lineCount[i]){
      //如果这行是在do中的，那么我们就暂时把这个东西放到缓冲区
      if(ifDO >= 0){
        strcat(buffer[ifDO] , yytext);
      }else{
        ECHO;
      }
      break;
    }
  }
}

%%

int main(int argc, char *argv[]){
  yylineno = 1;
  ifDO = -1;
  ifDel = 0;
  nesting = 0;
  lastNesting = 0;
  lastindex = 0;
  smallnesting = 0;
  lastPindex = 0;
  /*首先把输入和输出文件规定好*/
  if(argc > 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
    if(!(yyout = fopen(argv[2],"w"))){
      //这里将会返回一个基本可编译的C语言文件
      perror(argv[2]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");


  yylex();


}
