import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class YouTubeS extends StatefulWidget {
  const YouTubeS({super.key});

  @override
  State<YouTubeS> createState() => _YouTubeSState();
}

class _YouTubeSState extends State<YouTubeS> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _hasSearchResult = false;
  List<dynamic> _searchResults = [];
  Map<String, dynamic>? _selectedTrack;
  Map<String, dynamic>? _trackData;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _currentTrackIndex = -1;
  Map<String, dynamic>? _lyricsData;
  bool _loadingLyrics = false;

  // Color definitions
  final Color primaryDark = Color(0xFF0A0A0A);
  final Color cardDark = Color(0xFF1A1A1A);
  final Color accentRed = Color(0xFFDC143C);

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });
  }

  Future<void> _searchTrack() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearchResult = false;
      _searchResults = [];
      _selectedTrack = null;
      _trackData = null;
      _currentTrackIndex = -1;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _lyricsData = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.zenzxz.my.id/api/search/youtube?query=${_searchController.text}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _searchResults = data['data'];
            _hasSearchResult = true;
          });
        } else {
          _showError('Tidak ada hasil ditemukan');
        }
      } else {
        _showError('Gagal menghubungi server');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectTrack(Map<String, dynamic> track, int index) async {
    setState(() {
      _selectedTrack = track;
      _currentTrackIndex = index;
      _isLoading = true;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _lyricsData = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.deline.web.id/downloader/ytmp3?url=${track['url']}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null) {
          setState(() {
            _trackData = {
              'title': data['result']['youtube']['title'],
              'thumbnail': data['result']['youtube']['thumbnail'],
              'download_url': data['result']['dlink'],
              'quality': data['result']['pick']['quality'],
              'size': data['result']['pick']['size'],
            };
          });
          _fetchLyrics(data['result']['youtube']['title']);
          _playTrack();
        } else {
          _showError('Gagal mendownload track');
        }
      } else {
        _showError('Gagal menghubungi server');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLyrics(String title) async {
    setState(() {
      _loadingLyrics = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.deline.web.id/tools/lyrics?title=${Uri.encodeComponent(title)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null && data['result'].isNotEmpty) {
          setState(() {
            _lyricsData = data['result'][0];
          });
        }
      }
    } catch (e) {
      print('Error fetching lyrics: $e');
    } finally {
      setState(() {
        _loadingLyrics = false;
      });
    }
  }

  void _playPreviousTrack() {
    if (_searchResults.isNotEmpty && _currentTrackIndex > 0) {
      final previousIndex = _currentTrackIndex - 1;
      _selectTrack(_searchResults[previousIndex], previousIndex);
    }
  }

  void _playNextTrack() {
    if (_searchResults.isNotEmpty && _currentTrackIndex < _searchResults.length - 1) {
      final nextIndex = _currentTrackIndex + 1;
      _selectTrack(_searchResults[nextIndex], nextIndex);
    }
  }

  Future<void> _playTrack() async {
    if (_trackData != null && _trackData!['download_url'] != null) {
      final url = _trackData!['download_url'];
      await _audioPlayer.play(UrlSource(url));
    }
  }

  Future<void> _pauseTrack() async {
    await _audioPlayer.pause();
  }

  Future<void> _stopTrack() async {
    await _audioPlayer.stop();
    setState(() {
      _position = Duration.zero;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: Text(
          'YouTube Music',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: cardDark,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Youtube Search',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: cardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _searchTrack(),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: accentRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.search, color: Colors.white),
                    onPressed: _isLoading ? null : _searchTrack,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_hasSearchResult && _searchResults.isNotEmpty && _selectedTrack == null)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final track = _searchResults[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            track['thumbnail'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: Color(0xFF2A2A2A),
                              child: Icon(Icons.music_note, color: Colors.grey),
                            ),
                          ),
                        ),
                        title: Text(
                          track['title'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              track['author']['name'],
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.grey.shade500, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  track['timestamp'],
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.visibility, color: Colors.grey.shade500, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  '${(track['views'] as num).formatViews()}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.play_arrow, color: accentRed),
                        onTap: () => _selectTrack(track, index),
                      ),
                    );
                  },
                ),
              )
            else if (_selectedTrack != null && _trackData != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _trackData!['thumbnail'],
                                width: double.infinity,
                                height: 280,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 200,
                                  height: 200,
                                  color: Color(0xFF2A2A2A),
                                  child: Icon(Icons.music_note, color: Colors.grey, size: 60),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              _trackData!['title'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              _selectedTrack!['author']['name'],
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.music_note, color: Colors.grey.shade400, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  _trackData!['quality'],
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Icon(Icons.storage, color: Colors.grey.shade400, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  _trackData!['size'],
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Slider(
                              value: _position.inSeconds.toDouble(),
                              min: 0,
                              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                              onChanged: (value) async {
                                await _audioPlayer.seek(Duration(seconds: value.toInt()));
                              },
                              activeColor: accentRed,
                              inactiveColor: Colors.grey.shade700,
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.skip_previous, color: Colors.white, size: 30),
                                  onPressed: _currentTrackIndex > 0 ? _playPreviousTrack : null,
                                ),
                                SizedBox(width: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentRed,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    onPressed: _isPlaying ? _pauseTrack : _playTrack,
                                  ),
                                ),
                                SizedBox(width: 16),
                                IconButton(
                                  icon: Icon(Icons.skip_next, color: Colors.white, size: 30),
                                  onPressed: _currentTrackIndex < _searchResults.length - 1 ? _playNextTrack : null,
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      if (_loadingLyrics)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: accentRed),
                                SizedBox(height: 8),
                                Text(
                                  'Mencari lirik...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_lyricsData != null)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.library_music, color: accentRed),
                                  SizedBox(width: 8),
                                  Text(
                                    'Lirik Lagu',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(),
                                  if (_lyricsData!['artistName'] != null)
                                    Text(
                                      _lyricsData!['artistName'],
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                height: 200,
                                child: SingleChildScrollView(
                                  child: Text(
                                    _lyricsData!['plainLyrics'] ?? 'Lirik tidak tersedia',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTrack = null;
                            _trackData = null;
                            _currentTrackIndex = -1;
                            _audioPlayer.stop();
                            _position = Duration.zero;
                            _duration = Duration.zero;
                            _isPlaying = false;
                            _lyricsData = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2A2A2A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Cari Lagu Lain',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: accentRed,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _selectedTrack == null ? 'Mencari lagu...' : 'Mendownload track...',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note,
                        color: Colors.grey.shade600,
                        size: 80,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Cari lagu favoritmu',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Masukkan judul lagu atau nama artis',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension FormatNumber on num {
  String formatViews() {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toString();
  }

  String formatDuration() {
    final minutes = (this / 60).floor();
    final seconds = this % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
