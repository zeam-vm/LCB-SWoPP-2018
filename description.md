# はじめに

Node.jsでは，コールバックを用いてI/Oを非同期的に扱ってノンプリエンプティブなマルチタスクにする機構，Nodeプログラミングモデルが備わっている\cite{Node}．これにより，ウェブサーバーのメモリ使用量を格段に減らすことができ，同時セッション最大数やレイテンシが改善される\cite{NodeBenchmarks}．

もしNodeプログラミングモデルと同様の機構を，Javascriptよりパフォーマンスの良いプログラミング言語で実装したならば，ウェブサーバーの性能を格段に向上させることができる．そこで，我々は \Cpp とElixir \cite{Elixir} の2つのプログラミング言語を選んで実装を試みた． \Cpp を選んだのは，RFIDのような極端に小規模で消費電力の少ないような電子回路を用いてIoTデバイスを構築することを意図し，できるだけ小さなメモリ容量で実現でき，かつ \Cpp 11 はNodeプログラミングモデルの実現に必要な匿名関数を備えているからである．Elixirを選んだのは，Elixirで書かれたウェブサーバーフレームワークであるPhoenixを用いることで，極めてレスポンス性の高いウェブサーバーを構築できる \cite{Elixir16} からである．

我々の \Cpp への実装を Zackernel と称し，Elixir への実装を軽量コールバックスレッドと称している．これらを組合わせることで，世界中にばらまいた膨大な数のRFIDによる極小IoTデバイスと，それらから随時リクエストを受け付けるIoTサーバーからなるIoTシステムを構築することができる．

本報告では，Zackernel と軽量コールバックスレッドをどのように実装したのかを紹介し，メモリ消費量に焦点を当てて評価を行なう．

本報告のこの後の構成は次のとおりである．第2章では着想の元となったNodeプログラミングモデルについて紹介する．第3章ではZackernelの設計と実装を，第4章では軽量コールバックスレッドの設計と実装をそれぞれ示す．第5章ではメモリ消費量の評価を行う．最後に第6章でまとめと将来課題について述べる．

# Nodeプログラミングモデル

Nodeプログラミングモデル\cite{Node}の一例として，Node.jsのウェブサイト\cite{NodeSite}に掲載されているプログラム例を\figref{fig:Node_sample}に示す．このウェブサーバーのプログラムを実行してウェブブラウザで `http://localhost:3000` にアクセスすると `Hello World` と表示される．このウェブサーバーに接続があるごとに，下記のコールバック関数が呼び出されるが，この際にスレッドを生成してスタック領域を確保するようなことはしない．

```javascript
(req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('Hello World\n');
}
```


\begin{figure}[tb]
\begin{verbatim}
const http = require('http');

const hostname = '127.0.0.1';
const port = 3000;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('Hello World\n');
});

server.listen(port, hostname, () => {
  console.log(
    'Server running at http://${hostname}:${port}/'
  );
});
\end{verbatim}
\centering
\caption{Node.js のコード例}
\ecaption{A Sample Code of Node.js}
\label{fig:Node_sample}
\end{figure}


コールバック関数は，この例のように**匿名関数**として定義することもできるため，プログラムのメソッドや関数の中に記述できる．そのため，処理の流れを分断することなくプログラミングできる．

コールバック関数の呼出しは，通常のメソッドや関数の呼出しと同等である．したがって，スタックメモリのような広大なメモリ領域を消費することなく，かつ迅速に呼び出すことができる．



# Zackernel

ZackernelはNodeプログラミングモデル\cite{Node}に着想を得て， \Cpp で実装した，コールバック関数を用いてマルチタスクを実現するライブラリである．同様のものに libevent\cite{libevent}があるが，Zackernel は \Cpp 11 で導入された匿名関数を用いることで可読性を改善している．

Zackernelのプログラム例を\figref{fig:Zackernel_code}に示す．

変数`led1`と`led2`はメモリマップドI/Oで接続されたLEDであるとする．`main`関数では，Zackernelを初期化したあと，Zackernelが提供する`fork`によって，関数`blinkLed1`と`blinkLed2`を並行に呼び出す．

`blinkLed1`中の`zLoop`は，引数に指定された(匿名)関数を無限ループさせる．`[&] {}`という記述は \Cpp 11 で提供される匿名関数であり，外側の関数の名前空間を引き継いだ上で独立した関数を定義する．この中で `led1 = true;`を実行することで LED1 を点灯したあと，Zackernelが提供する`sleep`によって第1引数で指定されている500msの間スリープした後，第2引数で指定する(匿名)関数を実行する．この中で LED1 を消灯し，500msの間スリープする．ここまで実行したところで`zLoop`の作用により，再び`led1 = true;`を実行する．

`blinkLed2`も同様であるが，先にLED2を消灯してから500msスリープしLED2を点灯して500msスリープして先頭に戻る．結果として，これらのコードにより，LED1とLED2を交互に500msおきに点滅させることができる．

\begin{figure}[tb]
\begin{verbatim}
volatile bool led1 = false;
volatile bool led2 = false;

void blinkLed1() {
  zLoop([&] {
     led1 = true;
     sleep(500, [&] {
       led1 = false;
       sleep(500, [&] {});
     });
  });
}

void blinkLed2() {
  zLoop([&] {
     led2 = false;
     sleep(500, [&] {
       led1 = true;
       sleep(500, [&] {});
     });
  });
}

void main() {
  Zackernel::init();
  fork(blinkLed1, blinkLed2);
}
\end{verbatim}
\centering
\caption{Zackernel のコード例}
\ecaption{A Sample Code of Zackernel}
\label{fig:Zackernel_code}
\end{figure}

Zackernelの内部構成について説明する\cite{WSA2018-1}．Zackernel のScheduleクラスはコールバックする関数を保持し，Schedule同士を線形リスト構造でつないでいる．ZackernelのZackernelクラスはScheduleのキューを保持する．核心となるdispatchメソッドは，次に呼び出すべき関数をキューから読み込んで呼び出す．dispatchに再入している時にはコールバックする関数を呼び出さない，そうでない場合のみコールバックする関数を呼び出すロジックにすることで，スタックオーバーフローにならないようにしている．

Zackernel はノンプリエンプティブであるので，長い処理を実行すると制御が戻らない．我々は長い処理のほとんどはループかスリープであることに着目した．ループとしては`zLoop, zFor, zWhile, zDoWhile`を用意しており，それぞれ，無限ループ，`for`文，`while`文，`do while`文に対応する．これらはループ1回分(さらには条件文1回分)を実行したのちに，実行可能なタスクが他にないかを確認し，もしあればそのタスクに実行権を譲って実行可能待ちに入る．

またスリープとしては`sleep`を用意している．`sleep`は第1引数に待ち時間，第2引数にコールバック関数を取る．意味としては`sleep`を実行してから第1引数に指定した時間を待った後で第2引数に与えられたコールバック関数を呼び出す．実現方法としては，まず，`sleep`の待ち行列を形成し，それぞれで次の`sleep`待ちタスクを起こす時刻を記録しておく．実行可能なタスクがなくなった時点で，次の`sleep`待ちタスクの起動時刻が，それまでに実行可能なタスクで消費した時間を加味して起動すべき時刻になっていると判定した場合，そのタスクを実行する．起動すべき時刻になっていない場合にはじめて本当にスリープする．

このようにループとスリープを実装することで，ノンプリエンプティブでありながら，実用上問題なく使えるようになった．

Zackernelのコード行数は約900行であり，すべて \Cpp で記述されておりアセンブリ言語を一切含まない．プロセスやスレッドでマルチタスクを実現した場合には必ずアセンブリ言語記述を含み機種依存が生じてしまうが，Zackernelではこの問題は生じない．

# 軽量コールバックスレッド

軽量コールバックスレッドはNodeプログラミングモデル\cite{Node}に着想を得て，Elixir で実装した，コールバック関数を用いてマルチタスクを実現するライブラリである．現状では Elixir で記述されている．

軽量コールバックスレッドを用いたElixirプログラム例を\figref{fig:LCB_code}に示す．`pid = ZeamCallback.Receptor.new` で軽量コールバックスレッドを保持するプロセスを生成し，`pid`にプロセスIDを格納する．続く2つの`send(pid, {:spawn, ...}) ` は，それぞれ1つずつ軽量コールバックスレッドを新規作成して起動する．引数で与えられた`fn(tid) -> `から`end`までがコールバックされる匿名関数である．`IO.puts` は文字列を表示する関数である．`tid` には軽量コールバックスレッドのIDが格納される．1つめの軽量コールバックスレッドでは，`tid`の値が0なので，`foo 0`が表示される．2つめの軽量コールバックスレッドでは `tid` の値が1なので，`bar 0`が表示される．これらが順番に実行するようにスケジュールされるので，`foo 0`，`bar 1`と表示される．

\begin{figure}[tb]
\begin{verbatim}
pid = ZeamCallback.Receptor.new
send(pid, {:spawn, 
  fn(tid) ->
    IO.puts "foo #{tid}" 
  end})
send(pid, {:spawn, 
  fn(tid) -> 
    IO.puts "bar #{tid}" 
  end})
\end{verbatim}
\centering
\caption{軽量コールバックスレッドのコード例}
\ecaption{A Sample Code of Light-weight Callback Threads}
\label{fig:LCB_code}
\end{figure}

軽量コールバックスレッドの実装にあたり，ReceptorとWorkerという2つのElixirプロセスを用意する．Receptor は軽量コールバックスレッドへのリクエストを受取り，すぐさまWorkerにコマンドを送った後，すぐに次のリクエストを待つ．こうすることで，遅滞なくリクエストを受け取ることができるようにする．

一方，WorkerはReceptorのプロセスIDと実行環境変数`env`を引数とする関数である．`env`には現状では次の3つの情報が入っている．

* `:queue`: 実行キュー，すなわち次以降に実行するコールバック関数の待ち行列を表すリスト．
* `:threads`: 現在の軽量コールバックスレッドIDとコールバック関数の対応関係を保持するマップ．
* `:next_tid`: 次に軽量コールバックスレッドを新規生成した時のIDを記録する．

Workerは最初にReceptorからのすべてのコマンドを受け取り，実行キュー`env[:queue]`に登録していく．Receptorからのコマンドが空になったら，実行キューからコマンドを1つ取り出し，そのコマンドの軽量コールバックスレッドのIDを引数にしてコマンドが指す関数をコールバックしてWorkerを再帰呼び出しする．実行キューに何もなかった場合は10msスリープして，Workerを再帰呼び出しする．

Workerの持つ環境変数は，適宜Receptorに送られてバックアップされる．将来的には，もしWorkerが何らかの理由で無反応になってしまったときにはWorkerを再起動する機能を実装する予定である．

軽量コールバックスレッドの基本機能は正味約150行で構成される．Elixirのみで記述されており，他言語は用いていない．


# 評価

実験で用いた環境を\tabref{tab:environment}に示す．

\begin{table}[tb]
\centering
\caption{実行環境}
\ecaption{Runtime Environment}
\label{tab:environment}
\begin{tabular}{l|l}
                       & Mac Pro (Mid 2010)     \\ \hline
OS                     & macOS Sierra 10.12.6   \\
Elixir                 & 1.6.1 (OTP 20.3.6)     \\
\end{tabular}
\end{table}

Zackernelのメモリ消費量を \Cpp 11スレッドを用いた場合と比較する評価実験を行なった．C言語によるmacOSでのメモリ消費量の測定には `mach/mach.h` に定義している `task_basic_info` 構造体を用いて `virtual_size` で示される仮想メモリサイズを用いた．この値はバイト単位で表されるが，実際にはページ単位でメモリを扱うので，ページサイズの倍数値になる．そのため，ページサイズより小さなメモリ量の変化は測定結果に現れない．また，何回か実行するとばらつきを持った測定値となったので，繰返し測定して最初に3回同じ測定値になった場合の値を採用した．作成するスレッドの数は1,10,100,1000,2000,5000,10000,20000,50000の9通りで測定した．これらの測定結果を最小2乗法で傾きを求めることで，1スレッドあたりの使用メモリ量を測定した．

Zackernelと \Cpp 11スレッドのメモリ消費量を比較した実験結果を\tabref{tab:resultsZ}に示す．それぞれの相関係数は，Zackernelで0.8396， \Cpp 11スレッドで0.99993であった． \Cpp 11スレッドでは良好な結果が得られたと判断できるが，Zackernel ではスレッド数が小さい場合にページサイズより小さなメモリ変化しかなかったので測定値に現れず，結果的に相関係数の絶対値が小さくなった．Zackernel では1スレッドあたり204バイト， \Cpp 11スレッドでは1スレッドあたり約546KB消費していることがわかった．すなわち，Zackernel は \Cpp 11スレッドの約2,700分の1のメモリ消費量である．
 

\begin{table}[tb]
\centering
\caption{実験結果: Zackernelと \Cpp 11スレッドのメモリ消費量の比較(表)}
\ecaption{Results: Table of Comparison of Memory Size of Zackernel and \Cpp 11 Thread}
\label{tab:resultsZ}
\begin{tabular}{l|
>{\columncolor[HTML]{C0C0C0}}l
l}
Num. of Tasks & Zackernel    & \Cpp 11 Thread \\ \hline
1             & 0            & 536576     \\
10            & 0            & 5365760    \\
100           & 0            & 53657600   \\
1000          & 2097152      & 537624576  \\
2000          & 2097152      & 1094123520 \\
5000          & 4194304      & N/A        \\
10000         & 5242880      & N/A        \\
20000         & 7340032      & N/A        \\
50000         & 10485760     & N/A          
\end{tabular}
\end{table}



\begin{figure*}[t]
\centering
\includegraphicS[width=0.6\linewidth]{memory-callback-process.png}
\caption{実験結果: 軽量コールバックスレッドとプロセスのメモリ消費量の比較(散布図)}
\ecaption{Results: Scatterplot of Comparison of Memory Size of Light-weight Callback Threads and Processes}
\label{fig:results}
\end{figure*}


\begin{table}[tb]
\centering
\caption{実験結果: 軽量コールバックスレッドとプロセスのメモリ消費量の比較(表)}
\ecaption{Results: Table of Comparison of Memory Size of Light-weight Callback Threads and Processes}
\label{tab:results}
\begin{tabular}{r
>{\columncolor[HTML]{C0C0C0}}r r}
\multicolumn{1}{l}{Num. of Tasks} & \multicolumn{1}{l}{\cellcolor[HTML]{C0C0C0}CallBack (bytes)} & \multicolumn{1}{l}{Process (bytes)} \\
100                                             & 76144                                                        & 358848                              \\
1000                                            & 881656                                                       & 2877360                             \\
2000                                            & 1496296                                                      & 5636232                             \\
5000                                            & 5734120                                                      & 14160616                            \\
10000                                           & 13004640                                                     & 28402248                           
\end{tabular}
\end{table}

また軽量コールバックスレッドのメモリ消費量を，Elixirプロセスを用いた場合と比較する評価実験を行なった．Elixir にはメモリ消費量を測定するために `:erlang.memory` という関数が用意されている．この関数は全体のメモリ量やプロセスで使用しているメモリ量などを集計することができる．本研究では，軽量コールバックスレッドもしくはElixirプロセスを一定数新規作成する前後の全体のメモリ量の変化を計測した．作成するスレッドもしくはプロセスの数は100, 1000, 2000, 5000, 10000の5通りで測定した．これらの測定結果を最小2乗法で傾きを求めることで，1スレッドもしくは1プロセスあたりの使用メモリ量を測定した．

軽量コールバックスレッドとElixirプロセスのメモリ消費量を比較した実験結果を\tabref{tab:results}と\figref{fig:results}に示す．それぞれの相関係数は軽量コールバックスレッドの場合で0.99284，Elixirプロセスの場合で0.99998であったので，実験結果は良好であったと考えられる．傾きより，軽量コールバックスレッドの場合で1スレッドあたり1332バイト，Elixirプロセスの場合で1プロセスあたり2835バイト消費していることがわかった．すなわち，軽量コールバックスレッドはプロセスの約半分のメモリ消費量である．

これらの1スレッド/プロセスあたりのメモリ消費量を比較すると，Zackernel が204バイトと最も少なく，軽量コールバックスレッドが1332バイト，Elixirプロセスが2835バイトと続き， \Cpp 11 スレッドが約546KBとなる．処理系レベルから設計を見直すことで，軽量コールバックスレッドをZackernel並みのメモリ消費量に抑える最適化を施せる余地があるのかもしれない．


# まとめと将来課題

本研究ではNodeプログラミングモデルと同様の機構を \Cpp と Elixir で実装，それぞれ Zackernel，軽量コールバックスレッドと呼称した．

これらと従来のプロセス/スレッドとの1プロセス/スレッドあたりのメモリ消費量を比較する評価実験を行なった．その結果，Zackernel は1スレッドあたり204バイトと最も少なく，軽量コールバックスレッドが1スレッドあたり1332バイト，Elixirプロセスが1プロセスあたり2835バイト，\Cpp 11スレッドが1スレッドあたり約546KBであった．

将来課題としては，まずそれぞれの方法でコンテキストスイッチにどのくらいの時間を要するのかを測定することが挙げられる．コンテキストスイッチに要する時間は，マルチプロセス／マルチスレッドのシステム実装を評価する際に，1スレッド/プロセスあたりのメモリ消費量と並んで重要な特性値である．今後，環境を整備して測定を試みたい．

本提案方式は，現状ではノンプリエンプティブであるため，利用できる状況が限られる．Zackernel ではプリエンプティブマルチタスクと同様の使い勝手にするために，ループ中の1回1回の繰返しの際に他のタスクが起動可能かを判定するロジックを実装した．この方式をより使いやすくするために，プログラミング言語処理系に手を入れて，プログラム中のループにフックを挿入する事を考えている．また，Elixirにおいても，ループの代わりに用いられる再帰呼び出しや，EnumやFlow\cite{Flow}を用いたmap計算のようなまとまった処理を実行する際に，Zackernelと同様の仕組みを入れる方式が考えられる．

Zackernel はトリッキーなプログラミングになっていることから保守性が悪く，メモリリークの問題がまだ多く残っている．メモリリークが起こっている理由としては，通常の \Cpp プログラム同様，ガーベジコレクションされないという要因もありうるが，そのほかにも，Elixir のような関数型言語ではなく \Cpp で実装しているため，末尾再帰の最適化がなされないことから，コールバックする際に再帰呼び出しが深くなってしまう要因もありうる．

軽量コールバックスレッドについては，現状では実行キューで保持されているメモリ領域を適切に解放していないので，GCが有効に機能しない問題があるので，改善したい．プロセス間通信の仕組みを実装することで，ようやく実用的なプログラムを書くことができる．もしそれが実現できた時には，軽量コールバックスレッドを用いるように Phoenix を実装しなおすことを考えている \cite{WSA2018-1}．また，Zackernel 並みに1スレッドあたりのメモリ消費量を抑えるような言語処理系の設計・実装を試みる．


